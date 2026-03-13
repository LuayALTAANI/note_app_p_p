import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:note_app_pp/ui/widgets/audio_player_widget.dart';
import 'package:uuid/uuid.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/storage/file_manager.dart';
import 'package:note_app_pp/ui/common/video_meta.dart';

final _uuid = const Uuid();

Future<void> createFolder(
  BuildContext context,
  AppDatabase db,
  String parentId,
) async {
  final name = await promptTextDialog(
    context,
    title: 'Folder name',
    hint: 'e.g., Work',
    multiline: false,
  );
  if (name == null || name.trim().isEmpty) return;

  final id = _uuid.v4();
  final now = DateTime.now();

  await db.foldersDao.upsertFolder(
    FoldersCompanion.insert(
      id: id,
      parentId: Value(parentId),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
      sortMode: const Value('name'),
      orderIndex: const Value(0),
    ),
  );
}

Future<void> createNote(
  BuildContext context,
  AppDatabase db,
  String folderId,
) async {
  final title = await promptTextDialog(
    context,
    title: 'Note title (optional)',
    hint: 'Title',
    multiline: false,
  );

  final text = await promptTextDialog(
    context,
    title: 'Note text',
    hint: 'Write here...',
    multiline: true,
  );
  if (text == null) return;

  final id = _uuid.v4();
  final now = DateTime.now();

  await db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: id,
      folderId: folderId,
      type: 'note',
      title: Value(title?.trim().isEmpty ?? true ? null : title!.trim()),
      createdAt: now,
      updatedAt: now,
      mainType: 'note',
      mainData: text,
      meta: const Value(null),
    ),
  );

  if (context.mounted) context.push('/item/$id');
}

Future<void> createVoiceNote(
  BuildContext context,
  AppDatabase db,
  String folderId,
) async {
  final title = await promptTextDialog(
    context,
    title: 'Voice title (optional)',
    hint: 'Title',
    multiline: false,
  );

  final fm = FileManager();
  final path = await fm.createNewPrivateFile(extension: '.m4a');

  final recorded = await AudioPlayerWidget.recordToFile(
    context,
    outputPath: path,
  );

  if (!recorded) return;

  final assetId = _uuid.v4();
  final now = DateTime.now();

  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: path,
      mimeType: const Value('audio/m4a'),
      createdAt: now,
      sizeBytes: Value(await File(path).length()),
    ),
  );

  final itemId = _uuid.v4();
  await db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: itemId,
      folderId: folderId,
      type: 'voice',
      title: Value(title?.trim().isEmpty ?? true ? null : title!.trim()),
      createdAt: now,
      updatedAt: now,
      mainType: 'voice',
      mainData: assetId,
      meta: const Value(null),
    ),
  );

  if (context.mounted) context.push('/item/$itemId');
}

Future<void> importImage(
  BuildContext context,
  AppDatabase db,
  String folderId,
) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return;

  final fm = FileManager();
  final destPath = await fm.importFileToPrivateStorage(File(x.path));
  final assetId = _uuid.v4();
  final now = DateTime.now();

  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: destPath,
      mimeType: const Value('image/*'),
      createdAt: now,
      sizeBytes: Value(await File(destPath).length()),
    ),
  );

  final itemId = _uuid.v4();
  await db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: itemId,
      folderId: folderId,
      type: 'photo',
      title: const Value(null),
      createdAt: now,
      updatedAt: now,
      mainType: 'photo',
      mainData: assetId,
      meta: const Value(null),
    ),
  );

  if (context.mounted) context.push('/item/$itemId');
}

Future<void> importVideo(
  BuildContext context,
  AppDatabase db,
  String folderId,
) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.video_file),
            title: const Text('Add local video'),
            onTap: () => Navigator.pop(ctx, 'local'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Add YouTube link'),
            onTap: () => Navigator.pop(ctx, 'youtube'),
          ),
        ],
      ),
    ),
  );

  if (type == null) return;

  final now = DateTime.now();

  if (type == 'youtube') {
    final url = await promptTextDialog(
      context,
      title: 'YouTube link',
      hint: 'https://youtube.com/watch?v=...',
      multiline: false,
    );
    final v = (url ?? '').trim();
    if (v.isEmpty) return;

    // YouTube-only: store url in mainData, meta sets playMode online.
    final itemId = _uuid.v4();
    await db.itemsDao.insertItem(
      ItemsCompanion.insert(
        id: itemId,
        folderId: folderId,
        type: 'video',
        title: const Value(null),
        createdAt: now,
        updatedAt: now,
        mainType: 'video',
        mainData: v,
        meta: Value(writeJsonMeta({'youtubeUrl': v, 'playMode': 'online'})),
      ),
    );

    if (context.mounted) context.push('/item/$itemId');
    return;
  }

  final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (x == null) return;

  final fm = FileManager();
  final destPath = await fm.importFileToPrivateStorage(File(x.path));
  final assetId = _uuid.v4();

  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: destPath,
      mimeType: const Value('video/*'),
      createdAt: now,
      sizeBytes: Value(await File(destPath).length()),
    ),
  );

  final itemId = _uuid.v4();
  await db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: itemId,
      folderId: folderId,
      type: 'video',
      title: const Value(null),
      createdAt: now,
      updatedAt: now,
      mainType: 'video',
      mainData: assetId,
      meta: const Value(null),
    ),
  );

  if (context.mounted) context.push('/item/$itemId');
}

Future<void> importPdf(
  BuildContext context,
  AppDatabase db,
  String folderId,
) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: false,
  );

  final path = res?.files.single.path;
  if (path == null) return;

  final fm = FileManager();
  final destPath = await fm.importFileToPrivateStorage(
    File(path),
    extension: '.pdf',
  );

  final assetId = _uuid.v4();
  final now = DateTime.now();

  await db.assetsDao.upsertAsset(
    FileAssetsCompanion.insert(
      id: assetId,
      path: destPath,
      mimeType: const Value('application/pdf'),
      createdAt: now,
      sizeBytes: Value(await File(destPath).length()),
    ),
  );

  final itemId = _uuid.v4();
  await db.itemsDao.insertItem(
    ItemsCompanion.insert(
      id: itemId,
      folderId: folderId,
      type: 'pdf',
      title: const Value(null),
      createdAt: now,
      updatedAt: now,
      mainType: 'pdf',
      mainData: assetId,
      meta: const Value(null),
    ),
  );

  if (context.mounted) context.push('/item/$itemId');
}

Future<String?> promptTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required bool multiline,
}) async {
  final c = TextEditingController();

  return showDialog<String?>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 8 : 1,
        textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
        onSubmitted: multiline ? null : (_) => Navigator.pop(context, c.text),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}