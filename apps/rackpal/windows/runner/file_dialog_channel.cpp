#include "file_dialog_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <cwctype>
#include <memory>
#include <optional>
#include <string>

#include "utils.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

// The channel Dart's `Win32FilePicker` talks to. Named in exactly one Dart
// file (`lib/src/session/file_picker.dart`) and asserted there by
// `session_layering_test.dart` RULE 7.
constexpr char kChannelName[] = "rackpal/file_dialog";

// THE WHOLE REASON THIS FILE EXISTS.
//
// Nothing below writes a registry key. RackPal's own code writes no
// registry key anywhere, which is the half of the ComDlg32 statement that
// is entirely ours; `registry_claim_test.dart` derives that from this
// source rather than from this comment.
//
//  * FOS_DONTADDTORECENT  — nothing is added under ComDlg32's
//    OpenSavePidlMRU, no shortcut appears in
//    %APPDATA%\Microsoft\Windows\Recent, and no jump-list entry is made,
//    so no project FILE NAME reaches the host. IT IS HALF A FIX, AND THE
//    OTHER HALF IS NOT OURS: the shell writes values under ComDlg32 that
//    RackPal does not control — at minimum LastVisitedPidlMRU (this
//    executable plus the last folder browsed) and CIDSizeMRU (this
//    executable, written even when the dialog is cancelled), which are
//    measured examples and not an inventory. No supported option prevents
//    them while this is an IFileDialog. Measured, not assumed — see the
//    header for the bounded statement and why it is stated as a bound.
//  * FOS_FORCEFILESYSTEM  — the result is always a real path, never a
//    virtual shell item that has no filesystem name for us to save to.
//  * FOS_NOCHANGEDIR      — the dialog must not move the PROCESS's current
//    directory. A relative path resolved later would then land somewhere
//    the user never chose.
constexpr FILEOPENDIALOGOPTIONS kSharedOptions =
    FOS_DONTADDTORECENT | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                   static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring utf16(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        utf16.data(), size);
  return utf16;
}

// A string argument, or nothing. Dart sends `null` for "let the OS decide",
// and an absent key and a null value must mean the same thing.
std::optional<std::wstring> StringArg(const EncodableMap* args,
                                      const char* key) {
  if (args == nullptr) {
    return std::nullopt;
  }
  auto it = args->find(EncodableValue(key));
  if (it == args->end()) {
    return std::nullopt;
  }
  const auto* value = std::get_if<std::string>(&it->second);
  if (value == nullptr || value->empty()) {
    return std::nullopt;
  }
  return Utf16FromUtf8(*value);
}

// Applies everything both dialogs share, `kSharedOptions` first.
//
// THE OPTIONS ARE READ BACK AND OR-ED, never assigned: `SetOptions` REPLACES
// the option set, so writing it blind would clear the defaults the shell
// applies for this dialog type — including `FOS_OVERWRITEPROMPT` on the
// save dialog, whose loss would silently overwrite a project the user
// picked by accident.
HRESULT ConfigureDialog(IFileDialog* dialog, const EncodableMap* args,
                        FILEOPENDIALOGOPTIONS extra) {
  FILEOPENDIALOGOPTIONS options = 0;
  HRESULT hr = dialog->GetOptions(&options);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetOptions(options | kSharedOptions | extra);
  if (FAILED(hr)) {
    return hr;
  }

  // `.rmpj` has no registered UTI and no MIME type, so the filter is the
  // extension and a label. The pattern carries the `*.`; the DEFAULT
  // extension does not — that difference is what the two calls below want.
  //
  // BOTH SPELLINGS IN ONE ENTRY, semicolon-separated, and one entry rather
  // than two on purpose (DR-015). Two entries would make a user who has
  // `.rackpal` files from an earlier build switch the filter combo to see
  // them, which is a discoverability cliff for the exact people least
  // likely to know the extension changed. One entry shows both in Open,
  // and `SetDefaultExtension` below still decides what a Save gets.
  //
  // ─────────────────────────────────────────────────────────────────────
  // D13: THE FILTER IS A NAMED KIND, NOT A FILTER STRING FROM DART
  // ─────────────────────────────────────────────────────────────────────
  // Board M3-F/4 (#162). This was hard-coded to the project filter and
  // fired `SetDefaultExtension(L"rmpj")` on BOTH dialogs, so a CSV import
  // could only be reached through "All files" and a Save As of anything
  // else acquired a project extension.
  //
  // Dart sends a KIND (`project`, `csv`, `device`) and never a
  // `COMDLG_FILTERSPEC`, and that is the decision D13 asks to get right the
  // first time, because D2 is the macOS port and would otherwise
  // reimplement a narrow contract and widen it twice. A Win32 filter string
  // does not port: `NSOpenPanel` wants `UTType`s or bare extensions, so a
  // raw pattern would have to be parsed back apart on the other platform. A
  // kind maps onto both, and an unknown kind falls back to the project
  // filter rather than showing the user nothing.
  //
  // ─────────────────────────────────────────────────────────────────────
  // M4-M1: A TABLE, BECAUSE THE THIRD KIND IS WHERE A TERNARY GOES WRONG
  // ─────────────────────────────────────────────────────────────────────
  // Board `#234`. Two kinds fit in `csv ? a : b` and three do not: the
  // filter choice and the default extension are TWO ternaries over one
  // condition, so a third kind nests both and the two can then disagree
  // about what `device` means. That is the same defect D13 closed, one
  // spelling further on — it fired `SetDefaultExtension(L"rmpj")` on a
  // dialog whose filter said something else.
  //
  // So the pair is one ROW, and adding a kind is adding a row rather than
  // editing two expressions. `kFileKinds[0]` is the fallback, which is why
  // `project` is first and why the loop below can simply not find a match.
  struct FileKind {
    const wchar_t* name;                // the Dart enum name, on the wire
    const COMDLG_FILTERSPEC* filters;
    UINT filter_count;
    const wchar_t* default_extension;   // no `*.`, unlike the pattern
  };

  // `.rppj` has no registered UTI and no MIME type, so a filter is an
  // extension and a label, and `.rpdx` is in the same position.
  //
  // EVERY SPELLING A BUILD HAS WRITTEN IS IN THE PATTERN (DR-179
  // section 11.178.3): `.rppj` today, `.rmpj` from DR-015, and the
  // pre-DR-015 `.rackmate`. `.rackpal` is gone from it, because the
  // product rename invented that one and no build ever wrote it.
  static const COMDLG_FILTERSPEC kProjectFilters[] = {
      {L"RackPal project", L"*.rppj;*.rmpj;*.rackmate"},
      {L"All files", L"*.*"},
  };
  static const COMDLG_FILTERSPEC kCsvFilters[] = {
      {L"Comma-separated values", L"*.csv"},
      {L"All files", L"*.*"},
  };
  // THIS ROW SAID IT NEEDED NO LEGACY SPELLING, ON THE GROUND THAT NO
  // BUILD HAD EVER WRITTEN A DEVICE TEMPLATE. That was true when it was
  // written and stopped being true when template export shipped, so
  // `.rmdx` is on a user's disk and DR-179 section 11.178.3 keeps it
  // opening (docs/06 section 7.3).
  static const COMDLG_FILTERSPEC kDeviceFilters[] = {
      {L"RackPal device template", L"*.rpdx;*.rmdx"},
      {L"All files", L"*.*"},
  };
  // The archive is in the same position, for the same reason: the shelf
  // under the data root is full of `.rmda` files this app wrote. `.rmlib`
  // is still absent, and that one is genuine: it was the pre-DR-015 name,
  // specified as a zip and cut by AC-042 before anything wrote one.
  static const COMDLG_FILTERSPEC kLibraryFilters[] = {
      {L"RackPal device library", L"*.rpda;*.rmda"},
      {L"All files", L"*.*"},
  };

  // THE FIRST KIND WHOSE FILTER IS NOT ONE FORMAT (PLAN-D, DR-029). A
  // floorplan arrives as a PNG, a JPEG or a PDF, and the three are one
  // gesture rather than three menu items, so the first entry lists all of
  // them and the per-format entries are conveniences below it.
  //
  // THE FILTER IS A COURTESY AND NEVER THE CHECK. The dialog decides what
  // the user SEES; `sniffImportKind` decides what is accepted, by content
  // (PLAN-D/4, M4-M4's rule). A file renamed to `.png` passes this filter
  // and is refused on its signature, which is the correct division: a
  // filter that refuses is a filter somebody works around with "All
  // files", and then the only real check is the one in Dart anyway.
  //
  // NO DEFAULT EXTENSION THAT MEANS ANYTHING. This kind is open-only:
  // nothing in this product SAVES a floorplan, it copies one into the
  // container. `png` is here because the struct requires a value and it
  // is the least surprising of the three; if a save path ever appears
  // this row is wrong and will need splitting.
  static const COMDLG_FILTERSPEC kFloorplanFilters[] = {
      {L"Floorplan (PNG, JPEG, PDF)", L"*.png;*.jpg;*.jpeg;*.pdf"},
      {L"PNG image", L"*.png"},
      {L"JPEG image", L"*.jpg;*.jpeg"},
      {L"PDF document", L"*.pdf"},
      {L"All files", L"*.*"},
  };

  // THE LOGO (`#590`, DR-217): the floorplan's three plus SVG, in a row of
  // its own because the floorplan import refuses SVG. Open only, and the
  // content sniff decides, for the floorplan's reasons above.
  static const COMDLG_FILTERSPEC kLogoFilters[] = {
      {L"Logo (PNG, JPEG, PDF, SVG)", L"*.png;*.jpg;*.jpeg;*.pdf;*.svg"},
      {L"PNG image", L"*.png"},
      {L"JPEG image", L"*.jpg;*.jpeg"},
      {L"PDF document", L"*.pdf"},
      {L"SVG image", L"*.svg"},
      {L"All files", L"*.*"},
  };

  static const FileKind kFileKinds[] = {
      {L"project", kProjectFilters, ARRAYSIZE(kProjectFilters), L"rppj"},
      {L"csv", kCsvFilters, ARRAYSIZE(kCsvFilters), L"csv"},
      {L"device", kDeviceFilters, ARRAYSIZE(kDeviceFilters), L"rpdx"},
      {L"library", kLibraryFilters, ARRAYSIZE(kLibraryFilters), L"rpda"},
      {L"floorplan", kFloorplanFilters, ARRAYSIZE(kFloorplanFilters), L"png"},
      {L"logo", kLogoFilters, ARRAYSIZE(kLogoFilters), L"png"},
  };

  const std::optional<std::wstring> file_type = StringArg(args, "fileType");
  const FileKind* kind = &kFileKinds[0];
  if (file_type.has_value()) {
    for (const FileKind& candidate : kFileKinds) {
      if (*file_type == candidate.name) {
        kind = &candidate;
        break;
      }
    }
  }

  // BOTH PROJECT SPELLINGS IN ONE ENTRY, semicolon-separated, and one entry
  // rather than two on purpose (DR-015). Two entries would make a user who
  // has `.rackpal` files from an earlier build switch the filter combo to
  // see them, which is a discoverability cliff for the exact people least
  // likely to know the extension changed. One entry shows both in Open, and
  // `SetDefaultExtension` below still decides what a Save gets.
  hr = dialog->SetFileTypes(kind->filter_count, kind->filters);
  if (FAILED(hr)) {
    return hr;
  }
  hr = dialog->SetFileTypeIndex(1);
  if (FAILED(hr)) {
    return hr;
  }
  // So a user who types `Smith` gets `Smith.rmpj`. Dart's
  // `SavePaths.forTarget` normalises the result anyway, in one place, and
  // still has to: the "All files" filter above lets the dialog hand back a
  // bare name. It also leaves a `.rackpal` the user is saving over
  // exactly where it is — the default extension applies to a name that has
  // none, not to one this app still recognises.
  hr = dialog->SetDefaultExtension(kind->default_extension);
  if (FAILED(hr)) {
    return hr;
  }

  if (auto label = StringArg(args, "confirmButtonText")) {
    dialog->SetOkButtonLabel(label->c_str());
  }
  if (auto name = StringArg(args, "suggestedName")) {
    dialog->SetFileName(name->c_str());
  }
  if (auto directory = StringArg(args, "initialDirectory")) {
    // BEST EFFORT, AND DELIBERATELY UNCHECKED. The stored directory can be
    // a path from another machine — `prefs.json` travels with a portable
    // installation. A failure here just means the shell picks the folder,
    // which is exactly the fallback Dart's `_initialDirectory` already
    // reasons about.
    ComPtr<IShellItem> folder;
    if (SUCCEEDED(::SHCreateItemFromParsingName(directory->c_str(), nullptr,
                                                IID_PPV_ARGS(&folder)))) {
      dialog->SetFolder(folder.Get());
    }
  }
  return S_OK;
}

// The chosen path, or nothing when the user cancelled.
//
// A CANCEL IS NOT AN ERROR and must not be reported as one: it is the one
// "nothing happened" the session layer allows, because the user is the one
// who made it happen. The shell says so with
// `HRESULT_FROM_WIN32(ERROR_CANCELLED)`.
void ShowAndReply(IFileDialog* dialog, HWND owner,
                  std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  HRESULT hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result->Success(EncodableValue());
    return;
  }
  if (FAILED(hr)) {
    result->Error("dialog_failed", "The file dialog could not be shown.");
    return;
  }

  ComPtr<IShellItem> item;
  hr = dialog->GetResult(&item);
  if (FAILED(hr)) {
    result->Error("dialog_failed", "The file dialog returned no selection.");
    return;
  }

  PWSTR path = nullptr;
  hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
  if (FAILED(hr) || path == nullptr) {
    result->Error("dialog_failed",
                  "The chosen item has no filesystem path.");
    return;
  }
  std::string utf8 = Utf8FromUtf16(path);
  ::CoTaskMemFree(path);
  result->Success(EncodableValue(utf8));
}

}  // namespace

void RegisterFileDialogChannel(flutter::FlutterEngine* engine, HWND owner) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          engine->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [owner](const flutter::MethodCall<EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const auto* args = std::get_if<EncodableMap>(call.arguments());

        // `Help > Open diagnostics folder...` (DR-194, #941). Asks Explorer
        // to show a folder: ShellExecuteW's "open" verb on a directory, with
        // no arguments and no working directory. OUR code here writes no
        // registry key, which registry_claim_test checks against this
        // source. What Explorer records about a folder it was asked to open
        // is the shell's, not ours, and the folder is the diagnostics
        // folder, never a project's. Success is ShellExecute's own
        // contract, a return value above 32.
        if (call.method_name() == "revealFolder") {
          const std::optional<std::wstring> folder = StringArg(args, "path");
          if (!folder) {
            result->Error("bad_args", "revealFolder needs a path.");
            return;
          }
          const HINSTANCE shown = ::ShellExecuteW(
              owner, L"open", folder->c_str(), nullptr, nullptr,
              SW_SHOWNORMAL);
          result->Success(
              EncodableValue(reinterpret_cast<INT_PTR>(shown) > 32));
          return;
        }

        // "Open web page" (NET-A/4a, #994, DR-048 §11.47.7, DR-229). The
        // same act as revealFolder: ShellExecuteW's "open" verb, here on a
        // URL the user has just seen and confirmed. THE SCHEME IS CHECKED
        // HERE TOO, not only in Dart: "open" on `file:///...cmd.exe` runs a
        // program, and this end must not trust that every future caller of
        // the channel checked first. Only http:// and https:// pass, case
        // folded as URL schemes are. OUR code writes no registry key; what
        // the browser records about a page it was asked to open is the
        // browser's.
        if (call.method_name() == "openUrl") {
          const std::optional<std::wstring> url = StringArg(args, "url");
          if (!url) {
            result->Error("bad_args", "openUrl needs a url.");
            return;
          }
          std::wstring scheme = url->substr(0, url->find(L':'));
          for (auto& c : scheme) {
            c = static_cast<wchar_t>(::towlower(c));
          }
          if (scheme != L"http" && scheme != L"https") {
            result->Success(EncodableValue(false));
            return;
          }
          const HINSTANCE opened = ::ShellExecuteW(
              owner, L"open", url->c_str(), nullptr, nullptr, SW_SHOWNORMAL);
          result->Success(
              EncodableValue(reinterpret_cast<INT_PTR>(opened) > 32));
          return;
        }

        const bool saving = call.method_name() == "save";
        if (!saving && call.method_name() != "open") {
          result->NotImplemented();
          return;
        }

        ComPtr<IFileDialog> dialog;
        HRESULT hr = ::CoCreateInstance(
            saving ? CLSID_FileSaveDialog : CLSID_FileOpenDialog, nullptr,
            CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
        if (FAILED(hr)) {
          result->Error("dialog_failed",
                        "The file dialog could not be created.");
          return;
        }

        // FOS_FILEMUSTEXIST on open only: Save As names a file that does
        // not exist yet, which is the entire point of it.
        hr = ConfigureDialog(dialog.Get(), args,
                             saving ? FOS_OVERWRITEPROMPT
                                    : (FOS_FILEMUSTEXIST | FOS_PATHMUSTEXIST));
        if (FAILED(hr)) {
          result->Error("dialog_failed",
                        "The file dialog could not be configured.");
          return;
        }

        ShowAndReply(dialog.Get(), owner, std::move(result));
      });

  // The channel outlives this call and is owned by the engine's lifetime.
  // Releasing it here would tear the handler down before the first Ctrl+O.
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> retained;
  retained = std::move(channel);
}
