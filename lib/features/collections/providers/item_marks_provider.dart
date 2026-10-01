import 'dart:async';

import 'package:core/models/item_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../likes/providers/marked_units_provider.dart';

/// Key identifying a unit within an item.
typedef UnitKey = ({String unitType, int parent, int unit});

/// State holding every mark of one collection item, indexed by unit.
class ItemMarksState {
  const ItemMarksState({this.marks = const <UnitKey, ItemMark>{}});

  /// Marks keyed by their unit coordinates.
  final Map<UnitKey, ItemMark> marks;

  /// The mark for a unit, or null.
  ItemMark? markFor(String unitType, int parent, int unit) =>
      marks[(unitType: unitType, parent: parent, unit: unit)];

  /// Whether a unit is liked.
  bool isLiked(String unitType, int parent, int unit) =>
      markFor(unitType, parent, unit)?.isFavorite ?? false;

  /// The note on a unit (null when absent/empty).
  String? noteFor(String unitType, int parent, int unit) =>
      markFor(unitType, parent, unit)?.note;

  /// All marks as a flat list.
  List<ItemMark> get all => marks.values.toList();

  /// Liked count restricted to one unit type.
  int likedCountOfType(String unitType) => marks.values
      .where((ItemMark m) => m.unitType == unitType && m.isFavorite)
      .length;

  /// Commented count restricted to one unit type.
  int commentedCountOfType(String unitType) => marks.values
      .where((ItemMark m) => m.unitType == unitType && m.note != null)
      .length;
}

/// Marks provider, keyed by `collection_items.id` so it is universal across
/// media types.
final NotifierProviderFamily<ItemMarksNotifier, ItemMarksState, int>
    itemMarksProvider =
    NotifierProvider.family<ItemMarksNotifier, ItemMarksState, int>(
  ItemMarksNotifier.new,
);

/// Notifier managing a single item's marks.
class ItemMarksNotifier extends FamilyNotifier<ItemMarksState, int> {
  late DatabaseService _db;
  late int _itemId;

  /// Serializes writes so two quick taps persist in the order they were made,
  /// instead of racing and letting the later-arriving write win.
  Future<void> _writeChain = Future<void>.value();

  /// Bumped on every write; a `_load()` whose read resolves after a write is
  /// discarded rather than clobbering the fresher local patch.
  int _writeSeq = 0;

  @override
  ItemMarksState build(int itemId) {
    _itemId = itemId;
    _db = ref.watch(databaseServiceProvider);
    unawaited(_load());
    return const ItemMarksState();
  }

  Future<void> _load() async {
    final int seq = _writeSeq;
    final List<ItemMark> marks =
        await _db.itemMarkDao.getMarksForItem(_itemId);
    if (seq != _writeSeq) return; // A write landed while we were reading.
    state = ItemMarksState(
      marks: <UnitKey, ItemMark>{
        for (final ItemMark m in marks)
          (unitType: m.unitType, parent: m.parentNumber, unit: m.unitNumber):
              m,
      },
    );
  }

  /// Runs [body] after every previously queued write has settled, so DB writes
  /// land in call order even when the UI fires them without awaiting.
  Future<void> _serialize(Future<void> Function() body) {
    final Future<void> run = _writeChain.then((_) => body());
    _writeChain = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Toggles the like flag on a unit.
  Future<void> toggleFavorite(String unitType, int parent, int unit) async {
    // Wait for any in-flight write first: reading the flag before the previous
    // tap has landed would make two quick taps compute the same target.
    await _writeChain;
    await setFavorite(
      unitType,
      parent,
      unit,
      value: !state.isLiked(unitType, parent, unit),
    );
  }

  /// Sets the like flag on a unit to an explicit value.
  Future<void> setFavorite(
    String unitType,
    int parent,
    int unit, {
    required bool value,
  }) {
    _writeSeq++;
    final UnitKey key = (unitType: unitType, parent: parent, unit: unit);
    return _serialize(() async {
      final ItemMark? merged = await _db.itemMarkDao.setFavorite(
        _itemId,
        unitType,
        parent,
        unit,
        isFavorite: value,
      );
      _apply(key, merged);
    });
  }

  /// Sets the note on a unit (empty/null clears it).
  Future<void> setComment(
    String unitType,
    int parent,
    int unit,
    String? comment,
  ) {
    _writeSeq++;
    final UnitKey key = (unitType: unitType, parent: parent, unit: unit);
    return _serialize(() async {
      final ItemMark? merged = await _db.itemMarkDao
          .setComment(_itemId, unitType, parent, unit, comment);
      _apply(key, merged);
    });
  }

  /// Deletes a mark outright.
  Future<void> deleteMark(String unitType, int parent, int unit) {
    _writeSeq++;
    final UnitKey key = (unitType: unitType, parent: parent, unit: unit);
    return _serialize(() async {
      await _db.itemMarkDao.deleteMark(_itemId, unitType, parent, unit);
      _apply(key, null);
    });
  }

  /// Patches one unit in local state with the mark the DAO returned (null =
  /// row deleted), so no reload is needed after a write.
  void _apply(UnitKey key, ItemMark? mark) {
    final Map<UnitKey, ItemMark> next =
        Map<UnitKey, ItemMark>.of(state.marks);
    if (mark == null) {
      next.remove(key);
    } else {
      next[key] = mark;
    }
    state = ItemMarksState(marks: next);
    // The likes page aggregates every item; a mark set here must show up
    // there without a restart.
    ref.invalidate(markedUnitsProvider);
  }
}
