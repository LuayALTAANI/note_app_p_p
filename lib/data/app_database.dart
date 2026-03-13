
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dao/folders_dao.dart';
import 'dao/items_dao.dart';
import 'dao/blocks_dao.dart';
import 'dao/assets_dao.dart';

part 'app_database.g.dart';

class Folders extends Table {
  TextColumn get id => text()(); // UUID, and "root" for root folder
  TextColumn get parentId => text().nullable()();
  TextColumn get parentItemId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF9E9E9E))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get sortMode => text().withDefault(const Constant('name'))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get folderId => text()(); // points to folder.id ("root" allowed)

  /// 'note' | 'photo' | 'video' | 'voice' | 'pdf'
  TextColumn get type => text()();

  TextColumn get title => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  TextColumn get mainType => text()();

  /// for note -> text, for media -> assetId OR youtube url (if youtube-only)
  TextColumn get mainData => text()();

  /// NEW: JSON meta (youtubeUrl, playMode, etc.)
  TextColumn get meta => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DetailBlocks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text()(); // points to item.id
  TextColumn get type => text()(); // 'text' | 'photo' | 'video' | 'voice' | 'pdf' | 'folder'
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get data => text()(); // for text -> text, for media -> assetId, for folder -> folderId
  TextColumn get meta => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class FileAssets extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get path => text()(); // app-private file path
  TextColumn get mimeType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get checksum => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Folders, Items, DetailBlocks, FileAssets],
  daos: [FoldersDao, ItemsDao, BlocksDao, AssetsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          final now = DateTime.now();
          await into(folders).insert(
            FoldersCompanion.insert(
              id: 'root',
              parentId: const Value(null),
              parentItemId: const Value(null),
              name: 'Root',
              createdAt: now,
              updatedAt: now,
              sortMode: const Value('name'),
              orderIndex: const Value(0),
            ),
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 4) {
            await m.addColumn(folders, folders.color);
          }

          if (from < 5) {
            await m.addColumn(items, items.meta);
          }

          if (from == 1) {
            await m.addColumn(folders, folders.sortMode);
            await m.addColumn(folders, folders.orderIndex);

            final root = await (select(
              folders,
            )..where((t) => t.id.equals('root'))).getSingleOrNull();
            if (root == null) {
              final now = DateTime.now();
              await into(folders).insert(
                FoldersCompanion.insert(
                  id: 'root',
                  parentId: const Value(null),
                  parentItemId: const Value(null),
                  name: 'Root',
                  createdAt: now,
                  updatedAt: now,
                  sortMode: const Value('name'),
                  orderIndex: const Value(0),
                ),
              );
            }

            await (update(folders)
                  ..where((t) =>
                      t.parentId.isNull() & t.id.isNotIn(const ['root'])))
                .write(const FoldersCompanion(parentId: Value('root')));
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'note_app_pp.sqlite'));
    return NativeDatabase(file);
  });
}