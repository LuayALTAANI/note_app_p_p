import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:note_app_pp/data/app_database.dart';

enum VideoPlayMode { offline, online }

Map<String, dynamic> readJsonMeta(String? meta) {
  if (meta == null || meta.trim().isEmpty) return {};
  try {
    final d = jsonDecode(meta);
    return d is Map ? d.cast<String, dynamic>() : {};
  } catch (_) {
    return {};
  }
}

String writeJsonMeta(Map<String, dynamic> meta) => jsonEncode(meta);

String? metaYoutubeUrl(String? meta) {
  final m = readJsonMeta(meta);
  final v = (m['youtubeUrl'] ?? '').toString().trim();
  return v.isEmpty ? null : v;
}

VideoPlayMode metaPlayMode(String? meta, {VideoPlayMode fallback = VideoPlayMode.offline}) {
  final m = readJsonMeta(meta);
  final v = (m['playMode'] ?? '').toString().trim().toLowerCase();
  if (v == 'online') return VideoPlayMode.online;
  if (v == 'offline') return VideoPlayMode.offline;
  return fallback;
}

Future<void> setItemYoutubeUrl(AppDatabase db, Item item, String? youtubeUrl) async {
  final m = readJsonMeta(item.meta);
  final v = (youtubeUrl ?? '').trim();
  if (v.isEmpty) {
    m.remove('youtubeUrl');
  } else {
    m['youtubeUrl'] = v;
  }
  await db.itemsDao.updateMeta(item.id, m.isEmpty ? null : writeJsonMeta(m));
}

Future<void> setItemPlayMode(AppDatabase db, Item item, VideoPlayMode mode) async {
  final m = readJsonMeta(item.meta);
  m['playMode'] = mode == VideoPlayMode.online ? 'online' : 'offline';
  await db.itemsDao.updateMeta(item.id, writeJsonMeta(m));
}

Future<void> setBlockYoutubeUrl(AppDatabase db, DetailBlock block, String? youtubeUrl) async {
  final m = readJsonMeta(block.meta);
  final v = (youtubeUrl ?? '').trim();
  if (v.isEmpty) {
    m.remove('youtubeUrl');
  } else {
    m['youtubeUrl'] = v;
  }
  await (db.update(db.detailBlocks)..where((t) => t.id.equals(block.id))).write(
    DetailBlocksCompanion(
      meta: Value(m.isEmpty ? null : writeJsonMeta(m)),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<void> setBlockPlayMode(AppDatabase db, DetailBlock block, VideoPlayMode mode) async {
  final m = readJsonMeta(block.meta);
  m['playMode'] = mode == VideoPlayMode.online ? 'online' : 'offline';
  await (db.update(db.detailBlocks)..where((t) => t.id.equals(block.id))).write(
    DetailBlocksCompanion(
      meta: Value(writeJsonMeta(m)),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

String? tryExtractYoutubeId(String url) {
  final u = url.trim();
  if (u.isEmpty) return null;

  Uri? uri;
  try {
    uri = Uri.parse(u);
  } catch (_) {
    return null;
  }

  final host = (uri.host).toLowerCase();

  // youtu.be/<id>
  if (host.contains('youtu.be')) {
    final seg = uri.pathSegments;
    if (seg.isNotEmpty) return seg.first;
  }

  // youtube.com/watch?v=<id>
  if (host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;

    // youtube.com/embed/<id>, /shorts/<id>
    final seg = uri.pathSegments;
    final embedIdx = seg.indexOf('embed');
    if (embedIdx != -1 && embedIdx + 1 < seg.length) return seg[embedIdx + 1];
    final shortsIdx = seg.indexOf('shorts');
    if (shortsIdx != -1 && shortsIdx + 1 < seg.length) return seg[shortsIdx + 1];
  }

  return null;
}

bool looksLikeHttpUrl(String s) => s.trim().startsWith('http://') || s.trim().startsWith('https://');
