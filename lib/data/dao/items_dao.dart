
import 'package:drift/drift.dart';
import '../app_database.dart';

part 'items_dao.g.dart';

@DriftAccessor(tables: [Items])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Future<Item?> getById(String id) {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Item?> watchById(String id) {
    return (select(items)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<Item>> watchItemsInFolder(String folderId, String sortMode) {
    final q = select(items)..where((t) => t.folderId.equals(folderId));

    if (sortMode == 'date') {
      q.orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    } else if (sortMode == 'free') {
      q.orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    } else {
      q.orderBy([(t) => OrderingTerm(expression: t.title)]);
    }

    return q.watch();
  }

  Future<void> insertItem(ItemsCompanion companion) {
    return into(items).insert(companion);
  }

  Future<void> deleteItem(String id) async {
    await transaction(() async {
      await (delete(db.detailBlocks)..where((t) => t.itemId.equals(id))).go();

      final roots = await db.foldersDao.getFoldersForItem(id);
      for (final f in roots) {
        await db.foldersDao.deleteFolderTree(f.id);
      }

      await (delete(items)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> updateTitle(String itemId, String newTitle) {
    return (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        title: Value(newTitle),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMainData(String itemId, String newMainData) {
    return (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        mainData: Value(newMainData),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMeta(String itemId, String? metaJson) {
    return (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        meta: Value(metaJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMainTypeAndData(
    String itemId,
    String mainType,
    String mainData,
  ) {
    return (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        mainType: Value(mainType),
        mainData: Value(mainData),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorderItems(
    String folderId,
    List<String> orderedItemIds,
  ) async {
    await transaction(() async {
      for (var i = 0; i < orderedItemIds.length; i++) {
        final id = orderedItemIds[i];
        await (update(items)
              ..where((t) => t.id.equals(id) & t.folderId.equals(folderId)))
            .write(
          ItemsCompanion(
            orderIndex: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}