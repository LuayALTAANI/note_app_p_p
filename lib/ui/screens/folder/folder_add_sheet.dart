import 'package:flutter/material.dart';

import '../../../data/app_database.dart';
import 'folder_actions.dart';

Future<void> showFolderAddSheet({
  required BuildContext context,
  required AppDatabase db,
  required String folderId,
}) async {
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: const Text('New folder'),
            onTap: () async {
              Navigator.pop(context);
              await createFolder(context, db, folderId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.note),
            title: const Text('New note'),
            onTap: () async {
              Navigator.pop(context);
              await createNote(context, db, folderId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Import photo'),
            onTap: () async {
              Navigator.pop(context);
              await importImage(context, db, folderId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Import video'),
            onTap: () async {
              Navigator.pop(context);
              await importVideo(context, db, folderId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Import PDF'),
            onTap: () async {
              Navigator.pop(context);
              await importPdf(context, db, folderId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Record voice'),
            onTap: () async {
              Navigator.pop(context);
              await createVoiceNote(context, db, folderId);
            },
          ),
        ],
      ),
    ),
  );
}
