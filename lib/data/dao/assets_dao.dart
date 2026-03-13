import 'package:drift/drift.dart';
import '../app_database.dart';

part 'assets_dao.g.dart';

@DriftAccessor(tables: [FileAssets])
class AssetsDao extends DatabaseAccessor<AppDatabase> with _$AssetsDaoMixin {
  AssetsDao(super.db);

  Future<FileAsset?> getById(String id) => (select(fileAssets)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<void> upsertAsset(FileAssetsCompanion data) => into(fileAssets).insertOnConflictUpdate(data);
  Future<void> deleteAsset(String id) async {
    await (delete(fileAssets)..where((t) => t.id.equals(id))).go();
  }
}