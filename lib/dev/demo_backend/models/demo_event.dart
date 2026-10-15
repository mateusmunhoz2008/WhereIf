import 'package:autth_injustice_app/events/domain/models/event_preview.dart';

class DemoEvent {
  final EventPreview preview;
  final int? complementaryMinutes;

  const DemoEvent({
    required this.preview,
    this.complementaryMinutes,
  }) : assert(complementaryMinutes == null || complementaryMinutes >= 0);
}
