import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:flutter/widgets.dart';

class InstitutionScope extends InheritedWidget {
  final InstitutionPackage package;

  const InstitutionScope({
    super.key,
    required this.package,
    required super.child,
  });

  static InstitutionPackage of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InstitutionScope>();
    if (scope == null) {
      throw StateError('InstitutionScope is missing above this context.');
    }
    return scope.package;
  }

  @override
  bool updateShouldNotify(InstitutionScope oldWidget) {
    return oldWidget.package.id != package.id ||
        oldWidget.package.version != package.version;
  }
}

extension InstitutionContext on BuildContext {
  InstitutionPackage get institution => InstitutionScope.of(this);
}
