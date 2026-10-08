// SFE-C5 (DR-245 §11.244.1): a device file carries the signal families its
// ports name that do not ship, and is written at v4 only when it does.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// A shipped family to clone, and a free line for the clone.
SignalFamilyDef _clone(String name, {String parent = 'ctl.cresnet'}) {
  final doc = RackDocument(
    id: const Uuid('doc-library-families'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026, 10, 8),
    modifiedAt: DateTime.utc(2026, 10, 8),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 10, 8),
      updatedAt: DateTime.utc(2026, 10, 8),
      updatedBy: 'test',
    ),
  )..registries = buildSeedRegistries();
  final from = doc.registries.signalFamilies[SignalFamilyId(parent)]!;
  final free = cloneHeadroom(doc, from.domain)!.free.first;
  final built = buildCloneSignalFamily(
    doc,
    parent: from.id,
    displayName: name,
    shortTag: name.substring(0, 3).toUpperCase(),
    dashPermille: free.dashPermille,
    weightPermille: free.weightPermille,
  );
  return (built as CloneSignalFamilyReady).command.family;
}

/// A shipped template whose first port carries [carries] and whose second
/// accepts [accepts].
TemplateBody _body({SignalFamilyId? carries, SignalFamilyId? accepts}) {
  final body = buildSeedCatalog().values.firstWhere(
    (b) => b.ports.length >= 2,
  );
  if (carries != null) body.ports[0].signalFamily = carries;
  if (accepts != null) body.ports[1].acceptedFamilies = [accepts];
  return body;
}

void main() {
  final vantage = _clone('Vantage');
  final savant = _clone('Savant');
  final registries = buildSeedRegistries()
    ..signalFamilies[vantage.id] = vantage
    ..signalFamilies[savant.id] = savant;

  group('familiesToCarry', () {
    test('carries a clone a port carries AND one a port accepts, and no '
        'shipped family', () {
      final carried = familiesToCarry([
        _body(carries: vantage.id, accepts: savant.id),
      ], registries);
      expect([for (final f in carried) f.id], [savant.id, vantage.id]);
    });

    test('carries nothing for a device that uses only shipped families', () {
      expect(familiesToCarry([_body()], registries), isEmpty);
    });

    test('an id nothing defines is left out, not invented', () {
      expect(
        familiesToCarry([
          _body(carries: const SignalFamilyId('ctl.nowhere')),
        ], registries),
        isEmpty,
      );
    });
  });

  group('.rmdx', () {
    DeviceTemplateFile file(List<SignalFamilyDef> families) =>
        DeviceTemplateFile(
          templateId: const TemplateId('tpl.test'),
          version: 1,
          contentHash: 'unhashed:tpl.test@1',
          body: _body(carries: vantage.id),
          signalFamilies: families,
        );

    test('a file that carries a family is v4, and round-trips byte-exact '
        'with it', () {
      final bytes = encodeRmdxBytes(file([vantage]));
      expect(rmdxToJsonTree(file([vantage]))['schemaVersion'], 4);
      final back = (readRmdxBytes(bytes) as Ok<DeviceTemplateFile>).value;
      expect(back.signalFamilies.single.id, vantage.id);
      expect(back.signalFamilies.single.clonedFrom, vantage.clonedFrom);
      expect(utf8.decode(encodeRmdxBytes(back)), utf8.decode(bytes));
    });

    test('a file that carries none stays v3 with no new key, so it opens '
        'on every build that opened it before', () {
      final tree = rmdxToJsonTree(file(const []));
      expect(tree['schemaVersion'], 3);
      expect(tree.containsKey('signalFamilies'), isFalse);
    });
  });

  group('.rmda', () {
    DeviceLibraryFile library(List<SignalFamilyDef> families) =>
        DeviceLibraryFile(
          name: 'My library',
          templates: [
            DeviceTemplateFile(
              templateId: const TemplateId('tpl.test'),
              version: 1,
              contentHash: 'unhashed:tpl.test@1',
              body: _body(carries: vantage.id),
            ),
          ],
          signalFamilies: families,
        );

    test('a library that carries families is v4, and round-trips '
        'byte-exact with them, sorted', () {
      final bytes = encodeRmdaBytes(library([vantage, savant]));
      expect(rmdaToJsonTree(library([vantage]))['schemaVersion'], 4);
      final back = (readRmdaBytes(bytes) as Ok<DeviceLibraryFile>).value;
      expect(
        [for (final f in back.signalFamilies) f.id],
        [
          savant.id,
          vantage.id,
        ],
      );
      expect(utf8.decode(encodeRmdaBytes(back)), utf8.decode(bytes));
    });

    test('a library that carries none stays v3 with no new key', () {
      final tree = rmdaToJsonTree(library(const []));
      expect(tree['schemaVersion'], 3);
      expect(tree.containsKey('signalFamilies'), isFalse);
    });
  });
}
