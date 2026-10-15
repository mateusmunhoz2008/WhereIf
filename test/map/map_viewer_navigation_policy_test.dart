import 'package:autth_injustice_app/map/presentation/widgets/map_viewer_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const asset = 'assets/institutions/ifpr-pgua/map/viewer/index.html';

  test('only the bundled viewer document can navigate inside the map', () {
    for (final url in [
      'file:///android_asset/flutter_assets/$asset',
      'file:///private/App.framework/flutter_assets/$asset',
    ]) {
      expect(isMapViewerNavigationAllowed(url, asset), isTrue);
    }
    for (final url in [
      'https://example.com/flutter_assets/$asset',
      'http://localhost/flutter_assets/$asset',
      'file://remote/flutter_assets/$asset',
      'file://guest@/flutter_assets/$asset',
      'file:///private/data.html',
      'file:///android_asset/flutter_assets/${asset}x',
      'file:///android_asset/flutter_assets/$asset?external=true',
      'file:///android_asset/flutter_assets/$asset#external',
      'file:///android_asset/flutter_assets/../flutter_assets/$asset',
      'file:///android_asset/flutter_assets/%2e%2e/flutter_assets/$asset',
      'file:///android_asset/flutter_assets/%2E./flutter_assets/$asset',
      'file:///android_asset/flutter_assets/.%2E/flutter_assets/$asset',
      'file:///android_asset/./flutter_assets/$asset',
      'file:///android_asset/%2E/flutter_assets/$asset',
      'file:///android_asset/flutter_assets/%252e%252e/flutter_assets/$asset',
      'file:///android_asset/%2f../flutter_assets/$asset',
      'file:///android_asset/%2F../flutter_assets/$asset',
      'file:///android_asset/%5c../flutter_assets/$asset',
      'file:///android_asset/..\\flutter_assets/$asset',
      '../flutter_assets/$asset',
      'data:text/html,<script>alert(1)</script>',
      'javascript:alert(1)',
      'intent://example.com',
      'about:blank',
      'not a URL',
    ]) {
      expect(isMapViewerNavigationAllowed(url, asset), isFalse, reason: url);
    }
  });
}
