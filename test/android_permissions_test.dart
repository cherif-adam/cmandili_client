import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Google Play only allows READ_MEDIA_IMAGES / READ_MEDIA_VIDEO for apps whose
/// core feature is the photo gallery. The app picks photos with image_picker,
/// whose gallery path is the system picker (ACTION_GET_CONTENT, image/*): it
/// needs no media permission. These checks keep it that way.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the manifest does not declare the photo / video permissions', () {
    final declared = RegExp(r'<uses-permission[^>]*android\.permission\.(READ_MEDIA_\w+)')
        .allMatches(manifest)
        .map((m) => m.group(1))
        .toList();
    expect(declared, isEmpty);
  });

  test('no screen asks for photo access before picking', () {
    // Asking for Permission.photos / videos would need the permission above:
    // undeclared, Android answers "permanently denied" and the pick never
    // happens. Every pick must go straight to the picker.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (RegExp(r'Permission\.(photos|videos|mediaLibrary|storage)\b').hasMatch(s)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('photos are still picked with image_picker, gallery included', () {
    final pickers = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (s.contains('ImageSource.gallery')) pickers.add(f.path);
    }
    // Profile photo, parcel, bill, AI search and AI chat all keep a gallery
    // option.
    expect(pickers.length, greaterThanOrEqualTo(5));
  });
}
