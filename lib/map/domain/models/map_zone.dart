import 'package:flutter/foundation.dart';

@immutable
class MapZone {
  final String id;
  final String nodeName;
  final String label;
  final String? interiorResource;
  final bool focusOnVisualCenter;
  final bool constrainFocusToNavigation;
  final List<double>? focusDirection;
  final double focusDistanceScale;
  final List<double>? focusTargetOffset;

  const MapZone({
    required this.id,
    required this.nodeName,
    required this.label,
    this.interiorResource,
    this.focusOnVisualCenter = false,
    this.constrainFocusToNavigation = true,
    this.focusDirection,
    this.focusDistanceScale = 1,
    this.focusTargetOffset,
  });

  factory MapZone.fromJson(Map<String, dynamic> json) {
    return MapZone(
      id: json['id'] as String,
      nodeName: json['nodeName'] as String,
      label: json['label'] as String,
      interiorResource: json['interior'] as String?,
      focusOnVisualCenter: (json['focus']
              as Map<String, dynamic>?)?['useVisualCenter'] as bool? ??
          false,
      constrainFocusToNavigation: (json['focus']
              as Map<String, dynamic>?)?['constrainToNavigation'] as bool? ??
          true,
      focusDirection: switch (
          (json['focus'] as Map<String, dynamic>?)?['direction']) {
        final List<dynamic> values when values.length == 3 => List.unmodifiable(
            values.map((value) => (value as num).toDouble()),
          ),
        _ => null,
      },
      focusDistanceScale:
          ((json['focus'] as Map<String, dynamic>?)?['distanceScale'] as num?)
                  ?.toDouble() ??
              1,
      focusTargetOffset: switch (
          (json['focus'] as Map<String, dynamic>?)?['targetOffset']) {
        final List<dynamic> values when values.length == 3 => List.unmodifiable(
            values.map((value) => (value as num).toDouble()),
          ),
        _ => null,
      },
    );
  }
}
