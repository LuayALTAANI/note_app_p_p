import 'dart:convert';
import 'package:drift/drift.dart';

import 'package:note_app_pp/data/app_database.dart';

Map<String, dynamic> readBlockMeta(String? meta) {
  if (meta == null || meta.trim().isEmpty) return {};
  try {
    final d = jsonDecode(meta);
    return d is Map ? d.cast<String, dynamic>() : {};
  } catch (_) {
    return {};
  }
}

String defaultBlockTitle(DetailBlock b) => b.type.toUpperCase();

String blockTitle(DetailBlock b) {
  final meta = readBlockMeta(b.meta);
  final t = (meta['title'] ?? '').toString().trim();
  return t.isEmpty ? defaultBlockTitle(b) : t;
}

Future<void> setBlockTitle(
  AppDatabase db,
  DetailBlock block,
  String title,
) async {
  final meta = readBlockMeta(block.meta);
  meta['title'] = title.trim();

  await (db.update(db.detailBlocks)..where((t) => t.id.equals(block.id))).write(
    DetailBlocksCompanion(
      meta: Value(jsonEncode(meta)),
      updatedAt: Value(DateTime.now()),
    ),
  );
}
