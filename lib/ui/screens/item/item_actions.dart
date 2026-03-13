// lib/ui/screens/item/item_actions.dart
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:note_app_pp/ui/common/snackbar.dart';
import 'package:uuid/uuid.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/storage/file_manager.dart';
import 'package:note_app_pp/ui/common/confirm_dialog.dart';
import 'package:note_app_pp/ui/widgets/audio_player_widget.dart';
import 'item_rename_dialog.dart';
import 'package:note_app_pp/ui/common/video_meta.dart';

final _uuid = const Uuid();

Future<String?> _recordVoiceAssetId(BuildContext context, AppDatabase db) async {
  final fm = FileManager();
  final path = await fm.createNewPrivateFile(extension: '.m4a');

  final recorded = await AudioPlayerWidget.recordToFile(context, outputPath: path);

  if (!recorded) {
    await fm.deleteFileIfExists(path);
    return null;
  }

  final assetId = _uuid.v4();
  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: path,
      mimeType: const Value('audio/m4a'),
      createdAt: DateTime.now(),
      sizeBytes: Value(await File(path).length()),
    ),
  );

  return assetId;
}

Future<String?> _promptYoutubeUrl(BuildContext context) async {
  final url = await showRenameDialog(context, '');
  final v = (url ?? '').trim();
  if (v.isEmpty) return null;
  if (tryExtractYoutubeId(v) == null) return null;
  return v;
}

Future<void> addDetailBlock(BuildContext context, AppDatabase db, Item item) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.text_fields), title: const Text('Text'), onTap: () => Navigator.pop(ctx, 'text')),
          ListTile(leading: const Icon(Icons.photo), title: const Text('Photo'), onTap: () => Navigator.pop(ctx, 'photo')),
          ListTile(leading: const Icon(Icons.videocam), title: const Text('Video'), onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF'), onTap: () => Navigator.pop(ctx, 'pdf')),
          ListTile(leading: const Icon(Icons.mic), title: const Text('Voice'), onTap: () => Navigator.pop(ctx, 'voice')),
          ListTile(leading: const Icon(Icons.folder), title: const Text('Folder'), onTap: () => Navigator.pop(ctx, 'folder')),
        ],
      ),
    ),
  );
  if (type == null) return;

  final order = await db.blocksDao.watchBlocksForItem(item.id).first.then((l) => l.length);

  if (type == 'text') {
    await db.blocksDao.insertTextBlock(item.id, order);
    return;
  }

  if (type == 'folder') {
    final name = await showRenameDialog(context, 'New folder');
    if (name == null) return;

    final folderId = await db.foldersDao.createFolder(
      name: name.trim().isEmpty ? 'New folder' : name.trim(),
      parentItemId: item.id,
    );

    await db.blocksDao.insertFolderBlock(item.id, folderId, order);
    return;
  }

  if (type == 'voice') {
    final assetId = await _recordVoiceAssetId(context, db);
    if (assetId == null) return;

    await db.blocksDao.insertMediaBlock(item.id, 'voice', assetId, order);
    return;
  }

  if (type == 'video') {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.video_file), title: const Text('Add local video'), onTap: () => Navigator.pop(ctx, 'local')),
            ListTile(leading: const Icon(Icons.link), title: const Text('Add YouTube link'), onTap: () => Navigator.pop(ctx, 'youtube')),
          ],
        ),
      ),
    );
    if (mode == null) return;

    if (mode == 'youtube') {
      final url = await _promptYoutubeUrl(context);
      if (url == null) {
        showSnack(context, 'Invalid YouTube link');
        return;
      }
      await db.blocksDao.insertYoutubeVideoBlock(item.id, url, order);
      return;
    }

    final picked = (await ImagePicker().pickVideo(source: ImageSource.gallery))?.path;
    if (picked == null) return;

    final fm = FileManager();
    final newPath = await fm.importFileToPrivateStorage(File(picked));
    final assetId = _uuid.v4();

    await db.assetsDao.upsertAsset(
      FileAssetsCompanion.insert(
        id: assetId,
        path: newPath,
        mimeType: const Value('video/*'),
        createdAt: DateTime.now(),
        sizeBytes: Value(await File(newPath).length()),
      ),
    );

    await db.blocksDao.insertMediaBlock(item.id, 'video', assetId, order);
    return;
  }

  String? picked;
  if (type == 'photo') {
    picked = (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
  } else if (type == 'pdf') {
    picked = (await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']))?.files.single.path;
  }
  if (picked == null) return;

  final fm = FileManager();
  final newPath = await fm.importFileToPrivateStorage(File(picked));
  final assetId = _uuid.v4();

  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: newPath,
      createdAt: DateTime.now(),
      sizeBytes: Value(await File(newPath).length()),
    ),
  );

  await db.blocksDao.insertMediaBlock(item.id, type, assetId, order);
}

/// ✅ Main block: change media source for photo/video/pdf/voice.
Future<void> changeMainMedia(BuildContext context, AppDatabase db, Item item) async {
  if (item.mainType == 'note') return;

  // Helper: delete old asset if it's a local assetId.
  Future<void> deleteOldAssetIfAny(String assetId) async {
    if (assetId.trim().isEmpty) return;
    final old = await db.assetsDao.getById(assetId);
    if (old == null) return;
    await FileManager().deleteFileIfExists(old.path);
    await db.assetsDao.deleteAsset(old.id);
  }

  // PHOTO: replace with another gallery image
  if (item.mainType == 'photo') {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final fm = FileManager();
    final newPath = await fm.importFileToPrivateStorage(File(picked.path));
    final newAssetId = _uuid.v4();
    final now = DateTime.now();

    await db.assetsDao.upsertAsset(
      FileAssetsCompanion.insert(
        id: newAssetId,
        path: newPath,
        mimeType: const Value('image/*'),
        createdAt: now,
        sizeBytes: Value(await File(newPath).length()),
      ),
    );

    final oldAssetId = item.mainData;
    await db.itemsDao.updateMainTypeAndData(item.id, 'photo', newAssetId);
    await deleteOldAssetIfAny(oldAssetId);
    showSnack(context, 'Photo updated');
    return;
  }

  // PDF: replace with another PDF
  if (item.mainType == 'pdf') {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final fm = FileManager();
    final newPath = await fm.importFileToPrivateStorage(File(path), extension: '.pdf');
    final newAssetId = _uuid.v4();
    final now = DateTime.now();

    await db.assetsDao.upsertAsset(
      FileAssetsCompanion.insert(
        id: newAssetId,
        path: newPath,
        mimeType: const Value('application/pdf'),
        createdAt: now,
        sizeBytes: Value(await File(newPath).length()),
      ),
    );

    final oldAssetId = item.mainData;
    await db.itemsDao.updateMainTypeAndData(item.id, 'pdf', newAssetId);
    await deleteOldAssetIfAny(oldAssetId);
    showSnack(context, 'PDF updated');
    return;
  }

  // VOICE: re-record
  if (item.mainType == 'voice') {
    final newAssetId = await _recordVoiceAssetId(context, db);
    if (newAssetId == null) return;

    final oldAssetId = item.mainData;
    await db.itemsDao.updateMainTypeAndData(item.id, 'voice', newAssetId);
    await deleteOldAssetIfAny(oldAssetId);
    showSnack(context, 'Voice updated');
    return;
  }

  // VIDEO: keep your existing logic (YouTube <-> local) with minor structure.
  if (item.mainType == 'video') {
    final isYoutube = looksLikeHttpUrl(item.mainData);

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.video_file),
              title: const Text('Change to another local video'),
              onTap: () => Navigator.pop(ctx, 'local'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(isYoutube ? 'Change to another YouTube link' : 'Change to a YouTube link'),
              onTap: () => Navigator.pop(ctx, 'youtube'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'youtube') {
      final url = await _promptYoutubeUrl(context);
      if (url == null) {
        showSnack(context, 'Invalid YouTube link');
        return;
      }

      // local -> youtube: delete old asset
      if (!isYoutube && item.mainData.isNotEmpty) {
        final ok = await showConfirmDialog(
          context,
          title: 'Switch to YouTube?',
          message: 'This will replace the local video source with a YouTube link.',
        );
        if (!ok) return;

        await deleteOldAssetIfAny(item.mainData);
      }

      await db.itemsDao.updateMainTypeAndData(item.id, 'video', url);
      await setItemYoutubeUrl(db, item, url);
      await setItemPlayMode(db, item, VideoPlayMode.online);
      showSnack(context, 'YouTube link saved');
      return;
    }

    if (choice == 'local') {
      final pickedPath = (await ImagePicker().pickVideo(source: ImageSource.gallery))?.path;
      if (pickedPath == null) return;

      final fm = FileManager();
      final newPath = await fm.importFileToPrivateStorage(File(pickedPath));
      final newAssetId = _uuid.v4();

      await db.assetsDao.upsertAsset(
        FileAssetsCompanion.insert(
          id: newAssetId,
          path: newPath,
          mimeType: const Value('video/*'),
          createdAt: DateTime.now(),
          sizeBytes: Value(await File(newPath).length()),
        ),
      );

      // youtube -> local: clear yt meta
      if (isYoutube) {
        await db.itemsDao.updateMainTypeAndData(item.id, 'video', newAssetId);
        await setItemYoutubeUrl(db, item, null);
        await setItemPlayMode(db, item, VideoPlayMode.offline);
        showSnack(context, 'Local video set');
        return;
      }

      // local -> local: replace old asset
      final oldAssetId = item.mainData;
      await db.itemsDao.updateMainTypeAndData(item.id, 'video', newAssetId);
      await deleteOldAssetIfAny(oldAssetId);
      showSnack(context, 'Video updated');
      return;
    }
  }
}

Future<void> deleteItem(
  BuildContext context,
  AppDatabase db,
  Item item,
) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Delete item?',
    message: 'This will delete the item and all its content.',
  );
  if (!ok) return;

  final fm = FileManager();

  // Delete main asset if it is an offline media assetId.
  if (item.mainType != 'note' && item.mainType != 'video' && item.mainData.isNotEmpty) {
    final asset = await db.assetsDao.getById(item.mainData);
    if (asset != null) {
      await fm.deleteFileIfExists(asset.path);
      await db.assetsDao.deleteAsset(asset.id);
    }
  }
  if (item.mainType == 'video' && !looksLikeHttpUrl(item.mainData)) {
    final asset = await db.assetsDao.getById(item.mainData);
    if (asset != null) {
      await fm.deleteFileIfExists(asset.path);
      await db.assetsDao.deleteAsset(asset.id);
    }
  }

  final blocks = await db.blocksDao.watchBlocksForItem(item.id).first;
  for (final b in blocks) {
    if (b.type == 'folder') {
      await db.foldersDao.deleteFolderTree(b.data);
      await db.blocksDao.deleteBlock(b.id);
      continue;
    }

    if (b.type != 'text' && b.data.isNotEmpty) {
      final asset = await db.assetsDao.getById(b.data);
      if (asset != null) {
        await fm.deleteFileIfExists(asset.path);
        await db.assetsDao.deleteAsset(asset.id);
      }
    }
    await db.blocksDao.deleteBlock(b.id);
  }

  await db.itemsDao.deleteItem(item.id);
  if (context.mounted) Navigator.pop(context);
}