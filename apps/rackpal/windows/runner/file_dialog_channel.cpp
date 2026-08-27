#include "file_dialog_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <windows.h>
#include <wrl/client.h>

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
  // Dart sends a KIND (`project`, `csv`) and never a `COMDLG_FILTERSPEC`,
  // and that is the decision D13 asks to get right the first time,
  // because D2 is the macOS port and would otherwise reimplement a narrow
  // contract and widen it twice. A Win32 filter string does not port:
  // `NSOpenPanel` wants `UTType`s or bare extensions, so a raw pattern
  // would have to be parsed back apart on the other platform. A kind maps
  // onto both, and an unknown kind falls back to the project filter
  // rather than showing the user nothing.
  const std::optional<std::wstring> file_type = StringArg(args, "fileType");
  const bool csv = file_type.has_value() && *file_type == L"csv";

  COMDLG_FILTERSPEC project_filter[] = {
      {L"RackPal project", L"*.rmpj;*.rackpal"},
      {L"All files", L"*.*"},
  };
  COMDLG_FILTERSPEC csv_filter[] = {
      {L"Comma-separated values", L"*.csv"},
      {L"All files", L"*.*"},
  };
  hr = csv ? dialog->SetFileTypes(ARRAYSIZE(csv_filter), csv_filter)
           : dialog->SetFileTypes(ARRAYSIZE(project_filter), project_filter);
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
  hr = dialog->SetDefaultExtension(csv ? L"csv" : L"rmpj");
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
