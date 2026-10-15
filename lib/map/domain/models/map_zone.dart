import 'package:flutter/foundation.dart';

@immutable
class MapZone {
  final String id;
  final String nodeName;
  final String label;
  final String? interiorResource;
  final List<MapFloor> floors;
  final bool focusOnVisualCenter;
  final bool constrainFocusToNavigation;
  final List<double>? focusDirection;
  final double focusDistanceScale;
  final List<double>? focusTargetOffset;
  final List<double>? focusPosition;
  final List<double>? focusTarget;

  const MapZone({
    required this.id,
    required this.nodeName,
    required this.label,
    this.interiorResource,
    this.floors = const [],
    this.focusOnVisualCenter = false,
    this.constrainFocusToNavigation = true,
    this.focusDirection,
    this.focusDistanceScale = 1,
    this.focusTargetOffset,
    this.focusPosition,
    this.focusTarget,
  });

  factory MapZone.fromJson(Map<String, dynamic> json) {
    return MapZone(
      id: json['id'] as String,
      nodeName: json['nodeName'] as String,
      label: json['label'] as String,
      interiorResource: json['interior'] as String?,
      floors: (json['floors'] as List<dynamic>? ?? const [])
          .map((value) => MapFloor.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
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
      focusPosition: switch (
          (json['focus'] as Map<String, dynamic>?)?['position']) {
        final List<dynamic> values when values.length == 3 => List.unmodifiable(
            values.map((value) => (value as num).toDouble()),
          ),
        _ => null,
      },
      focusTarget: switch (
          (json['focus'] as Map<String, dynamic>?)?['target']) {
        final List<dynamic> values when values.length == 3 => List.unmodifiable(
            values.map((value) => (value as num).toDouble()),
          ),
        _ => null,
      },
    );
  }
}

@immutable
class MapFloor {
  final String id;
  final String label;
  final List<String> nodeNames;
  final List<Map<String, String>> spaces;

  const MapFloor(
      {required this.id,
      required this.label,
      required this.nodeNames,
      required this.spaces});

  factory MapFloor.fromJson(Map<String, dynamic> json) => MapFloor(
        id: json['id'] as String,
        label: json['label'] as String,
        nodeNames: List<String>.from(json['nodeNames'] as List),
        spaces: (json['spaces'] as List)
            .map((value) => Map<String, String>.from(value as Map))
            .toList(growable: false),
      );

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'nodeNames': nodeNames,
        'spaces': spaces,
      };
}
