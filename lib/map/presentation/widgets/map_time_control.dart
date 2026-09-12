import 'package:flutter/material.dart';
import 'package:autth_injustice_app/map/presentation/widgets/campus_map_viewport.dart';

class MapTimeControl extends StatelessWidget {
  final CampusMapViewportState viewport;

  const MapTimeControl({super.key, required this.viewport});

  static const _presets = <int, String>{
    0: 'Madrugada',
    360: 'Amanhecer',
    540: 'Manhã',
    720: 'Meio-dia',
    1080: 'Pôr do sol',
    1260: 'Noite',
  };

  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _label(int? minutes) =>
      minutes == null ? 'Hora atual' : _presets[minutes] ?? _clock(minutes);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
        valueListenable: viewport.previewMinutes,
        builder: (context, minutes, _) => PopupMenuButton<int>(
          tooltip: 'Escolher horário do mapa',
          initialValue: minutes ?? -1,
          onSelected: (value) async {
            if (value == -2) {
              final selected = await showTimePicker(
                context: context,
                helpText: 'Horário do mapa',
                cancelText: 'Cancelar',
                confirmText: 'Aplicar',
                initialTime: minutes == null
                    ? TimeOfDay.now()
                    : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (selected == null || !context.mounted) return;
              await viewport.previewTime(selected.hour * 60 + selected.minute);
            } else {
              await viewport.previewTime(value == -1 ? null : value);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: -1, child: Text('Usar hora atual')),
            const PopupMenuDivider(),
            for (final entry in _presets.entries)
              PopupMenuItem(
                  value: entry.key,
                  child: Text('${entry.value} · ${_clock(entry.key)}')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: -2, child: Text('Escolher hora…')),
          ],
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xD90D1423),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, color: Colors.white, size: 21),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(_label(minutes),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: Colors.white70, size: 18),
            ]),
          ),
        ),
      );
}
