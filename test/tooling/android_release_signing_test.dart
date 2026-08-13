import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release 使用外部 credentials 且不回退到 debug signing', () {
    final buildScript = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildScript, contains('id("org.jetbrains.kotlin.android")'));
    expect(buildScript, isNot(contains('getByName("debug")')));
    expect(buildScript, contains('key.properties'));
    expect(buildScript, contains('ANDROID_RELEASE_STORE_FILE'));
    expect(buildScript, contains('releaseBuildRequested'));
    expect(buildScript, contains('throw GradleException'));
  });

  test('Android release secrets 由 gitignore 排除', () {
    final rootIgnoreRules = File('.gitignore').readAsStringSync();

    expect(rootIgnoreRules, contains('/android/key.properties'));
    expect(rootIgnoreRules, contains('**/*.jks'));
    expect(rootIgnoreRules, contains('**/*.keystore'));
  });
}
