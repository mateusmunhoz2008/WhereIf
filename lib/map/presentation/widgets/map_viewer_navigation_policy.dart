bool isMapViewerNavigationAllowed(String url, String viewerAssetPath) {
  // Uri parsing removes dot segments, so validate their original spelling first.
  if (url.contains('\\') ||
      RegExp(r'%(?:2f|5c|25)', caseSensitive: false).hasMatch(url)) {
    return false;
  }
  final rawSegments =
      url.replaceAll(RegExp(r'%2e', caseSensitive: false), '.').split('/');
  if (rawSegments.any((part) => part == '.' || part == '..')) return false;

  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'file' ||
      uri.host.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return false;
  }
  if (uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.any((part) =>
          part == '..' ||
          part == '.' ||
          part.contains('/') ||
          part.contains('\\'))) {
    return false;
  }
  return uri.path.endsWith('/flutter_assets/$viewerAssetPath');
}
