import 'dart:convert';
import 'dart:io';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/domain/models/map_event_entry.dart';
import 'package:autth_injustice_app/events/domain/models/event_editor_draft.dart';
import 'package:autth_injustice_app/events/domain/models/event_details.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/domain/models/event_draft_validator.dart';
import 'package:autth_injustice_app/events/data/mappers/event_firestore_mapper.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/test_event_categories.dart';

void main() {
  final json = jsonDecode(
      File('assets/institutions/ifpr-pgua/map/campus_map.json')
          .readAsStringSync()) as Map;
  final zones =
      (json['zones'] as List).map((value) => MapZone.fromJson(value)).toList();
  final catalog = MapLocationCatalog('ifpr-pgua', zones);
  final room = catalog.locations
      .firstWhere((place) => place.spaceNodeName == 'sala_1_did');
  final floor = catalog.locations.firstWhere(
      (place) => place.floorId == 'didatico-p1' && place.spaceNodeName == null);
  final block =
      catalog.locations.firstWhere((place) => place.zoneId == 'quadra');
  EventPreview event(
          {String id = 'one',
          List<MapLocation>? locations,
          DateTime? publishAt,
          DateTime? cancelledAt}) =>
      EventPreview(
          id: id,
          title: 'Mostra de projetos',
          category: TestEventCategories.academic,
          startsAt: DateTime(2027, 1, 2),
          location: '',
          mapLocations: locations ?? [room, floor, block],
          description: 'Projetos feitos pelos estudantes.',
          imageUrl: 'image.jpg',
          endMode: EventEndMode.manual,
          publishAt: publishAt,
          cancelledAt: cancelledAt,
          cancellationReason: cancelledAt == null ? null : 'Cancelado',
          cancelledByUid: cancelledAt == null ? null : 'manager');
  test('catalogue offers room, entire floor and exterior without typed names',
      () {
    expect(room.zoneId, 'bloco-didatico');
    expect(room.floorId, 'didatico-p2');
    expect(floor.spaceNodeName, isNull);
    expect(block.floorId, isNull);
    final alias = MapLocation(
        institutionId: room.institutionId,
        zoneId: room.zoneId,
        floorId: room.floorId,
        spaceNodeName: room.spaceNodeName,
        label: 'Sala de Música');
    expect(catalog.resolve(alias), room,
        reason: 'Display names never change the destination');
    expect(
        catalog.resolve(const MapLocation(
            institutionId: 'other', zoneId: 'quadra', label: 'Quadra')),
        isNull);
  });
  test('legacy/malformed destinations cannot break an event catalogue', () {
    expect(MapLocation.readList(null), isEmpty);
    expect(MapLocation.readList('Sala 1'), isEmpty);
    expect(
        MapLocation.readList([
          {},
          room.toJson(),
          room.toJson(),
          {
            'institutionId': 'x',
            'zoneId': 'y',
            'label': 'z',
            'spaceNodeName': 'room'
          }
        ]),
        [room]);
  });
  test(
      'creation, editing, copy, clearing and Firestore preserve multiple destinations',
      () {
    final draft = EventEditorDraft(
        title: 'Mostra de projetos',
        category: TestEventCategories.academic,
        startsAt: DateTime(2027, 1, 2),
        endMode: EventEndMode.manual,
        mapLocations: [room, floor, block],
        description: 'Projetos feitos pelos estudantes.',
        selectedImageSource: 'image.jpg');
    expect(EventDraftValidator.validateLocation(draft), isNull);
    final preview = draft.toCreationInput().toPreview(id: 'one');
    expect(preview.mapLocations, [room, floor, block]);
    final data = EventFirestoreMapper.toMap(preview);
    final read = EventFirestoreMapper.previewFromMap(
        'one', data, const IfprPguaPackage());
    expect(read.mapLocations, [room, floor, block]);
    expect(read.displayLocation, contains('Sala 1'));
    final edit = EventEditorDraft.fromDetails(
        EventDetails(event: read, addedToPersonalHistory: false));
    expect(edit.mapLocations, [room, floor, block]);
    expect(edit.location, isNull);
    expect(
        edit.toUpdateInput().applyTo(read).mapLocations, [room, floor, block]);
    expect(
        edit
            .copyWith(mapLocations: const [])
            .toUpdateInput()
            .applyTo(read)
            .mapLocations,
        isEmpty);
    expect(
        EventDraftValidator.validateLocation(
            draft.copyWith(mapLocations: [room, room])),
        EventDraftValidationIssue.invalidLocation);
    final legacy = EventFirestoreMapper.previewFromMap(
        'one', {...data}..remove('mapLocations'), const IfprPguaPackage());
    expect(legacy.mapLocations, isEmpty);
    expect(legacy.location, isNotEmpty);
  });
  test('markers only contain visible active events and resolvable locations',
      () {
    final now = DateTime(2027, 1, 1);
    final valid = event();
    final pending =
        event(id: 'pending', publishAt: now.add(const Duration(days: 1)));
    final cancelled = event(id: 'cancelled', cancelledAt: now);
    final missing = event(id: 'missing', locations: const [
      MapLocation(institutionId: 'ifpr-pgua', zoneId: 'gone', label: 'Removido')
    ]);
    final entries = MapEventEntry.fromEvents(
        [valid, valid, pending, cancelled, missing], catalog, now);
    expect(entries.length, 1);
    expect(entries.first.locations, [room, floor, block]);
  });
  test(
      'exterior destination is the busiest whole floor, without double counting rooms',
      () {
    final secondRoom = catalog.locations
        .firstWhere((place) => place.spaceNodeName == 'sala_2_did');
    final broad = catalog.locations.firstWhere(
        (place) => place.zoneId == room.zoneId && place.floorId == null);
    final one = event(locations: [room, secondRoom, room]);
    final two = event(id: 'two', locations: [secondRoom]);
    final p1 = event(id: 'p1', locations: [floor]);
    final generic = event(id: 'generic', locations: [broad]);
    final entries = MapEventEntry.fromEvents([
      one,
      one,
      two,
      p1,
      generic,
      event(id: 'elsewhere', locations: [block])
    ], catalog, DateTime(2027, 1, 1));
    final summary = MapEventFloorSummary.fromEntries(
        entries, zones.firstWhere((zone) => zone.id == room.zoneId));
    expect(summary.counts, {'didatico-p1': 1, 'didatico-p2': 2});
    expect(summary.destination!.floorId, 'didatico-p2');
    expect(summary.destination!.spaceNodeName, isNull);
    expect(catalog.resolve(summary.destination!), isNotNull);
  });
  test(
      'floor ties follow metadata order, and multi-floor events count once per floor',
      () {
    final entries = MapEventEntry.fromEvents([
      event(locations: [room, floor])
    ], catalog, DateTime(2027, 1, 1));
    final summary = MapEventFloorSummary.fromEntries(
        entries, zones.firstWhere((zone) => zone.id == room.zoneId));
    expect(summary.counts, {'didatico-p1': 1, 'didatico-p2': 1});
    expect(summary.destination!.floorId, 'didatico-p1');
  });
  test(
      'generic building and court events stay outside, with no invented floor alerts',
      () {
    final broad = catalog.locations.firstWhere(
        (place) => place.zoneId == room.zoneId && place.floorId == null);
    final entries = MapEventEntry.fromEvents([
      event(locations: [broad, block])
    ], catalog, DateTime(2027, 1, 1));
    final summary = MapEventFloorSummary.fromEntries(
        entries, zones.firstWhere((zone) => zone.id == room.zoneId));
    expect(summary.counts.values.every((count) => count == 0), isTrue);
    expect(summary.destination!.floorId, isNull);
    expect(
        MapEventFloorSummary.fromEntries(
                entries, zones.firstWhere((zone) => zone.id == 'quadra'))
            .destination,
        block);
    expect(MapEventFloorSummary.fromEntries(const [], zones.first).destination,
        isNull);
  });
}
