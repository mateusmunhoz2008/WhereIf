import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('institution contracts do not depend on application features', () {
    final imports = RegExp(
      r'''(?:import|export)\s+['"]package:autth_injustice_app/([^'"]+)''',
    );
    final violations = <String>[];

    for (final file in Directory('lib/institution')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        if (!match.group(1)!.startsWith('institution/')) {
          violations.add('${file.path}: ${match.group(1)}');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('application features use institution contracts instead of IFPR data',
      () {
    final concreteImport = RegExp(
      r'''(?:import|export)\s+['"]package:autth_injustice_app/institution/packages/''',
    );
    final violations = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.startsWith('lib/institution/')) continue;
      if (concreteImport.hasMatch(file.readAsStringSync())) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty);
  });
}
