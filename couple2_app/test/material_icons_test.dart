import 'dart:io';

import 'package:couple2_app/app/material_icons.dart';
import 'package:couple2_app/modules/feed/ui/widgets/activity_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'material icons stay in the bundle and the warmup does not throw',
    () async {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('uses-material-design: true'));
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('MaterialIcons-Regular.otf'));
      await warmMaterialIcons();
      expect(Icons.person.fontFamily, 'MaterialIcons');
      expect(Icons.favorite.fontFamily, 'MaterialIcons');
      expect(
        identical(activityIcon('LIST_CREATED'), Icons.playlist_add),
        isTrue,
      );
      expect(
        identical(activityIcon('UNKNOWN'), Icons.notifications_none),
        isTrue,
      );
      expect(keptMaterialIcons, contains(Icons.arrow_back));
      expect(keptMaterialIcons, contains(Icons.favorite));
    },
  );
}
