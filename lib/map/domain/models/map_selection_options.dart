class MapSelectionOptions {
  final bool labels;
  final bool floors;
  final bool uiAnimation;
  final bool glass;

  const MapSelectionOptions({
    this.labels = true,
    this.floors = true,
    this.uiAnimation = true,
    this.glass = false,
  });

  factory MapSelectionOptions.fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return MapSelectionOptions(
      labels: flag('labels', true),
      floors: flag('floors', true),
      uiAnimation: flag('uiAnimation', true),
      glass: flag('glass', false),
    );
  }
}
