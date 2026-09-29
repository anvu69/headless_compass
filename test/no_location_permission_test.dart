import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The package must never contain a location-permission request.
///
/// Apple's upload scanner reads the compiled binary, not the call graph: a
/// `requestWhenInUseAuthorization` sitting in a branch the app never calls
/// still earns ITMS-90683 ("Missing purpose string in Info.plist") for every
/// app that links this package without declaring
/// `NSLocationWhenInUseUsageDescription`. 0.2.x carried exactly that, behind
/// `requestTrueNorth()`, and the one app using it got the email.
///
/// Magnetic heading needs no permission, so this package asks for none — and
/// this test is what keeps it that way. It scans source, not a binary, because
/// the selector name survives compilation verbatim: if it is in the Swift, it
/// is in the framework.
void main() {
  test('Swift sources contain no location-permission request', () {
    final forbidden = RegExp(
      r'requestWhenInUseAuthorization|requestAlwaysAuthorization'
      r'|requestTemporaryFullAccuracyAuthorization',
    );
    final hits = <String>[];
    for (final f in Directory('ios').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.swift')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (forbidden.hasMatch(code)) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: 'location-permission request found');
  });
}
