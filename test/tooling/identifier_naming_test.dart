import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_identifier_names.dart';

void main() {
  test('first-party Dart identifiers use complete semantic names', () {
    final violations = findIdentifierNamingViolations(
      projectDirectory: Directory.current,
    );

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
