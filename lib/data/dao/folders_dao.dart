import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';

part 'folders_dao.g.dart';

final _uuid = const Uuid();

@DriftAccessor(tables: [Folders])
class FoldersDao extends DatabaseAccessor<AppDatabase> with _$FoldersDaoMixin {
  FoldersDao(super.db);

  Stream<Folder?> watchById(String id) {
    return (select(folders)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> ensureRootFolder() async {
    final existing = await (select(
      folders,
    )..where((t) => t.id.equals('root'))).getSingleOrNull();
    if (existing != null) return;

    final now = DateTime.now();
    await into(folders).insert(
      FoldersCompanion.insert(
        id: 'root',
        parentId: const Value(null),
        name: 'Root',
        createdAt: now,
        updatedAt: now,
        sortMode: const Value('name'),
        orderIndex: const Value(0),
      ),
    );
  }

  Future<void> migrateTopLevelFoldersUnderRoot() async {
    await ensureRootFolder();
    await (update(folders)..where(
          (t) =>
              t.parentId.isNull() &
              t.parentItemId.isNull() &
              t.id.isNotIn(const ['root']),
        ))
        .write(const FoldersCompanion(parentId: Value('root')));
  }

  Future<void> upsertFolder(FoldersCompanion data) async {
    await into(folders).insertOnConflictUpdate(data);
  }

  Future<String> createFolder({
    required String name,
    String? parentId,
    String? parentItemId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(folders).insert(
      FoldersCompanion.insert(
        id: id,
        parentId: Value(parentId),
        parentItemId: Value(parentItemId),
        name: name,
        createdAt: now,
        updatedAt: now,
        sortMode: const Value('name'),
        orderIndex: const Value(0),
      ),
    );

    return id;
  }

  Future<List<Folder>> getFoldersForItem(String itemId) {
    return (select(folders)..where((t) => t.parentItemId.equals(itemId))).get();
  }

  Future<void> deleteFolderTree(String rootFolderId) async {
    await transaction(() async {
      
      final allFolderIds = <String>[rootFolderId];
      var cursor = 0;
      while (cursor < allFolderIds.length) {
        final current = allFolderIds[cursor++];
        final children = await (select(
          folders,
        )..where((t) => t.parentId.equals(current))).get();
        for (final c in children) {
          if (!allFolderIds.contains(c.id)) allFolderIds.add(c.id);
        }
      }

      final itemsRows = await (select(
        db.items,
      )..where((t) => t.folderId.isIn(allFolderIds))).get();
      final itemIds = itemsRows.map((e) => e.id).toList();

      if (itemIds.isNotEmpty) {
        await (delete(
          db.detailBlocks,
        )..where((t) => t.itemId.isIn(itemIds))).go();
        await (delete(db.items)..where((t) => t.id.isIn(itemIds))).go();
      }

      await (delete(folders)..where((t) => t.id.isIn(allFolderIds))).go();
    });
  }

  Future<void> setSortMode(String folderId, String mode) async {
    await (update(folders)..where((t) => t.id.equals(folderId))).write(
      FoldersCompanion(sortMode: Value(mode), updatedAt: Value(DateTime.now())),
    );
  }

  Stream<List<Folder>> watchChildren(String parentId, String sortMode) {
    final q = select(folders)
      ..where((t) => t.parentId.equals(parentId) & t.parentItemId.isNull());

    if (sortMode == 'date') {
      q.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    } else if (sortMode == 'free') {
      q.orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    } else {
      
      q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    }

    return q.watch();
  }

  Future<void> reorderFolders(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(folders)..where((t) => t.id.equals(orderedIds[i]))).write(
          FoldersCompanion(orderIndex: Value(i)),
        );
      }
    });
  }

  Future<void> deleteFolderIfEmpty(String folderId) async {
    final childrenCount =
        await (select(folders)..where((t) => t.parentId.equals(folderId)))
            .get()
            .then((rows) => rows.length);

    final itemsCount =
        await (select(db.items)..where((t) => t.folderId.equals(folderId)))
            .get()
            .then((rows) => rows.length);

    if (childrenCount > 0 || itemsCount > 0) {
      throw Exception('Folder must be empty to delete.');
    }

    await (delete(folders)..where((t) => t.id.equals(folderId))).go();
  }

  Future<void> updateColor(String folderId, int color) async {
    await (update(folders)..where((t) => t.id.equals(folderId))).write(
      FoldersCompanion(color: Value(color), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> renameFolder(String folderId, String newName) async {
    await (update(folders)..where((t) => t.id.equals(folderId))).write(
      FoldersCompanion(name: Value(newName), updatedAt: Value(DateTime.now())),
    );
  }
}