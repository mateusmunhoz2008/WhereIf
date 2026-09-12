import 'package:autth_injustice_app/institution/domain/models/institution_resource.dart';

abstract final class IfprPguaAssets {
  static const logoBlack = InstitutionResource.asset(
    path: 'assets/institutions/ifpr-pgua/branding/logo_black.png',
    kind: InstitutionResourceKind.rasterImage,
    contentType: 'image/png',
  );

  static const logoWhite = InstitutionResource.asset(
    path: 'assets/institutions/ifpr-pgua/branding/logo_white.png',
    kind: InstitutionResourceKind.rasterImage,
    contentType: 'image/png',
  );

  static const campusMapStandard = InstitutionResource.asset(
    path: 'assets/institutions/ifpr-pgua/map/campus_exterior_standard.glb',
    kind: InstitutionResourceKind.mapBundle,
    contentType: 'model/gltf-binary',
  );

  static const campusMapMetadata = InstitutionResource.asset(
    path: 'assets/institutions/ifpr-pgua/map/campus_map.json',
    kind: InstitutionResourceKind.mapMetadata,
    contentType: 'application/json',
  );
}
