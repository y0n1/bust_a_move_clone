// Regression tests for #95 — the web icon set and the manifest that declares it.
//
// A player reported two console errors on load: a deprecated Apple meta tag and
// a manifest icon the browser could not decode. The icons under `web/` had been
// saved as base64 *text* instead of binary PNGs, and `manifest.json` declared an
// icon file that was never added. Neither defect is reachable from Dart, and the
// engine/widget suites cannot see them, so these tests inspect the shipped
// static assets directly.
//
// They are deliberately strict about the *encoding*: the artwork itself is fine,
// which is exactly why the bug survived — every file decodes to a valid image,
// and only the bytes on disk were wrong.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 8-byte header every PNG starts with (RFC 2083 §3.1).
const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A,
  0x0A];

/// A PNG stores its dimensions in the IHDR chunk, which is always first:
/// 8 signature bytes, 4 length, 4 type ("IHDR"), then width and height as
/// big-endian 32-bit integers.
({int width, int height})? _pngSize(List<int> bytes) {
  if (bytes.length < 24) return null;
  if (!_hasPngSignature(bytes)) return null;
  if (String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') return null;
  int be32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  return (width: be32(16), height: be32(20));
}

bool _hasPngSignature(List<int> bytes) {
  if (bytes.length < _pngSignature.length) return false;
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) return false;
  }
  return true;
}

/// `flutter test` runs with the package root as the working directory.
File _webFile(String relativePath) {
  expect(
    File('pubspec.yaml').existsSync(),
    isTrue,
    reason: 'these tests must run from the package root (flutter test test/)',
  );
  return File('web/$relativePath');
}

void main() {
  group('web icon set (#95)', () {
    test('every shipped PNG is a binary PNG, not base64 text', () {
      final web = Directory('web');
      expect(web.existsSync(), isTrue, reason: 'web/ is the shipped web shell');

      final pngs = web
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(
        pngs,
        isNotEmpty,
        reason: 'a web build with no icons cannot install as an app',
      );

      for (final file in pngs) {
        final bytes = file.readAsBytesSync();
        expect(
          _hasPngSignature(bytes),
          isTrue,
          reason:
              '${file.path} does not start with the PNG signature. A file that '
              'begins with base64 text (typically "iVBORw0KGgo") renders as a '
              'broken image and the browser reports "resource isn\'t a valid '
              'image". Save the decoded bytes, not the encoding.',
        );
        expect(
          _pngSize(bytes),
          isNotNull,
          reason: '${file.path} has a PNG signature but no readable IHDR chunk',
        );
      }
    });

    test('every manifest icon exists and matches its declared size', () {
      final manifestFile = _webFile('manifest.json');
      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'web/manifest.json is what makes the app installable',
      );

      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final icons = (manifest['icons'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      expect(icons, isNotEmpty, reason: 'the manifest declares no icons');

      for (final icon in icons) {
        final src = icon['src'] as String;
        final file = _webFile(src);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'manifest.json declares "$src" but web/$src does not exist. A '
              'declared-but-missing icon is a 404 on every load and blocks the '
              'install prompt.',
        );

        final size = _pngSize(file.readAsBytesSync());
        if (size == null) fail('web/$src is not a readable PNG');

        final declared = (icon['sizes'] as String).split('x');
        expect(declared, hasLength(2), reason: 'malformed sizes for "$src"');
        expect(
          (width: int.parse(declared[0]), height: int.parse(declared[1])),
          size,
          reason:
              'web/$src is ${size.width}x${size.height} but manifest.json '
              'declares ${icon['sizes']}. Browsers size the install icon from '
              'the manifest, so a mismatch shows a distorted icon.',
        );
      }
    });

    test('index.html drops the deprecated Apple capable meta tag', () {
      final html = _webFile('index.html').readAsStringSync();

      expect(
        html,
        isNot(contains('apple-mobile-web-app-capable')),
        reason:
            'Chrome logs a deprecation warning for this tag. The standardised '
            'replacement is mobile-web-app-capable.',
      );
      expect(
        html,
        contains('name="mobile-web-app-capable"'),
        reason: 'the replacement tag must actually be present',
      );
    });
  });
}
