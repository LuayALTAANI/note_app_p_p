import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';

part 'blocks_dao.g.dart';

final _uuid = const Uuid();

@DriftAccessor(tables: [DetailBlocks])
class BlocksDao extends DatabaseAccessor<AppDatabase> with _$BlocksDaoMixin {
  BlocksDao(super.db);

  Stream<List<DetailBlock>> watchBlocksForItem(String itemId) {
    return (select(detailBlocks)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .watch();
  }

  Future<void> insertTextBlock(String itemId, int orderIndex) {
    final now = DateTime.now();
    return into(detailBlocks).insert(
      DetailBlocksCompanion.insert(
        id: _uuid.v4(),
        itemId: itemId,
        type: 'text',
        data: '',
        orderIndex: Value(orderIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> insertMediaBlock(
    String itemId,
    String type,
    String assetId,
    int orderIndex,
  ) {
    final now = DateTime.now();
    return into(detailBlocks).insert(
      DetailBlocksCompanion.insert(
        id: _uuid.v4(),
        itemId: itemId,
        type: type,
        data: assetId,
        orderIndex: Value(orderIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> insertFolderBlock(String itemId, String folderId, int orderIndex) {
    final now = DateTime.now();
    return into(detailBlocks).insert(
      DetailBlocksCompanion.insert(
        id: _uuid.v4(),
        itemId: itemId,
        type: 'folder',
        data: folderId,
        orderIndex: Value(orderIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// ✅ Fix: detail block accepts video links reliably (no insert+refetch race).
  /// Inserts a YouTube-only video block: data='' and meta contains youtubeUrl.
  Future<void> insertYoutubeVideoBlock(
    String itemId,
    String youtubeUrl,
    int orderIndex,
  ) {
    final now = DateTime.now();
    return into(detailBlocks).insert(
      DetailBlocksCompanion.insert(
        id: _uuid.v4(),
        itemId: itemId,
        type: 'video',
        data: '',
        meta: Value(jsonEncode({'youtubeUrl': youtubeUrl.trim()})),
        orderIndex: Value(orderIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateText(String blockId, String newText) {
    return (update(detailBlocks)..where((t) => t.id.equals(blockId))).write(
      DetailBlocksCompanion(
        data: Value(newText),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteBlock(String id) {
    return (delete(detailBlocks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderBlocks(String itemId, List<String> orderedBlockIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedBlockIds.length; i++) {
        final id = orderedBlockIds[i];
        await (update(detailBlocks)..where((t) => t.id.equals(id) & t.itemId.equals(itemId))).write(
          DetailBlocksCompanion(
            orderIndex: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
