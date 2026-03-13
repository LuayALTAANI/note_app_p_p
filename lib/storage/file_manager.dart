import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileManager {
  final _uuid = const Uuid();

  Future<Directory> _rootDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'note_app_pp_assets'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> importFileToPrivateStorage(File source, {String? extension}) async {
    final root = await _rootDir();
    final id = _uuid.v4();
    final ext = extension ?? p.extension(source.path);
    final dest = File(p.join(root.path, '$id$ext'));
    await source.copy(dest.path);
    return dest.path;
  }

  Future<String> createNewPrivateFile({required String extension}) async {
    final root = await _rootDir();
    final id = _uuid.v4();
    return p.join(root.path, '$id$extension');
  }

  Future<void> deleteFileIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}