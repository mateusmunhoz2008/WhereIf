import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/map/data/services/institution_map_metadata_loader.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';

class EventMapLocationSelector extends StatefulWidget {
  final List<MapLocation> selected;
  final ValueChanged<List<MapLocation>> onChanged;
  const EventMapLocationSelector(
      {super.key, required this.selected, required this.onChanged});
  @override
  State<EventMapLocationSelector> createState() =>
      _EventMapLocationSelectorState();
}

class _EventMapLocationSelectorState extends State<EventMapLocationSelector> {
  Future<List<MapLocation>>? _catalog;
  String? _source;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final institution = context.institution;
    final resource = institution.map.metadataResource;
    final source = '${institution.id}:${resource?.location}';
    if (source == _source) return;
    _source = source;
    _catalog = resource == null || !resource.isBundled
        ? Future.value(const [])
        : const InstitutionMapMetadataLoader().load(resource.location).then(
            (zones) => MapLocationCatalog(institution.id, zones).locations);
  }

  Future<void> _choose(List<MapLocation> locations) async {
    final selected = await showModalBottomSheet<List<MapLocation>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => EventMapLocationPicker(
            locations: locations, selected: widget.selected));
    if (mounted && selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FutureBuilder<List<MapLocation>>(
            future: _catalog,
            builder: (context, snapshot) => OutlinedButton.icon(
                  key: const ValueKey('event-map-location-choose'),
                  onPressed: snapshot.hasData && snapshot.data!.isNotEmpty
                      ? () => _choose(snapshot.data!)
                      : null,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(snapshot.hasError
                      ? context.l10n.mapLocationsUnavailable
                      : context.l10n.eventChooseMapLocations),
                )),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final location in widget.selected)
              InputChip(
                label: Text(location.label, softWrap: true),
                onDeleted: () => widget.onChanged(List.unmodifiable(
                    widget.selected.where((entry) => entry != location))),
              )
          ]),
        ],
      ]);
}

class EventMapLocationPicker extends StatefulWidget {
  final List<MapLocation> locations, selected;
  const EventMapLocationPicker(
      {super.key, required this.locations, required this.selected});
  @override
  State<EventMapLocationPicker> createState() => _EventMapLocationPickerState();
}

class _EventMapLocationPickerState extends State<EventMapLocationPicker> {
  late final Map<String, MapLocation> _selected = {
    for (final place in widget.selected) place.key: place
  };
  String _query = '';
  String _search(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàãâ]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
  @override
  Widget build(BuildContext context) {
    final matches = widget.locations
        .where((place) => _search(place.label).contains(_search(_query)))
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      final size = MediaQuery.sizeOf(context);
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      final covered = (keyboard - (size.height - constraints.maxHeight))
          .clamp(0.0, keyboard);
      return SizedBox(
          height: size.height * .82,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + covered),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Text(context.l10n.eventChooseMapLocations,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(context.l10n.eventMapLocationsHint),
                          const SizedBox(height: 12),
                          TextField(
                              key: const ValueKey('event-location-search'),
                              decoration: InputDecoration(
                                  hintText: context.l10n.mapSearchLocations,
                                  prefixIcon: const Icon(Icons.search)),
                              onChanged: (value) =>
                                  setState(() => _query = value)),
                          const SizedBox(height: 8),
                        ])),
                    matches.isEmpty
                        ? SliverToBoxAdapter(
                            child: Text(context.l10n.mapLocationsEmpty))
                        : SliverList.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final location = matches[index];
                              return CheckboxListTile(
                                  key: ValueKey('location-${location.key}'),
                                  value: _selected.containsKey(location.key),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(location.label),
                                  secondary: Icon(location.spaceNodeName != null
                                      ? Icons.meeting_room_outlined
                                      : location.floorId != null
                                          ? Icons.layers_outlined
                                          : Icons.apartment_outlined),
                                  onChanged: (checked) => setState(() {
                                        if (checked == true) {
                                          _selected[location.key] = location;
                                        } else {
                                          _selected.remove(location.key);
                                        }
                                      }));
                            }),
                  ])),
                  FilledButton(
                      key: const ValueKey('event-location-confirm'),
                      onPressed: () => Navigator.pop(context,
                          List<MapLocation>.unmodifiable(_selected.values)),
                      child: Text(context.l10n.continueButton)),
                ]),
          ));
    });
  }
}
