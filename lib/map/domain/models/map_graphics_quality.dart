enum MapGraphicsQuality {
  light('basic'),
  complete('cinematic');

  final String rendererProfile;

  const MapGraphicsQuality(this.rendererProfile);

  static MapGraphicsQuality? fromStorage(String? value) => switch (value) {
        'light' => MapGraphicsQuality.light,
        'complete' => MapGraphicsQuality.complete,
        _ => null,
      };
}
