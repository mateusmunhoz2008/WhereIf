enum MapClimate {
  automatic(null),
  morning(360),
  midday(720),
  sunset(1080),
  night(1260);

  final int? previewMinutes;
  const MapClimate(this.previewMinutes);

  MapClimate get next => values[(index + 1) % values.length];

  static MapClimate fromStorage(String? value) => MapClimate.values
      .firstWhere((mode) => mode.name == value, orElse: () => automatic);
}
