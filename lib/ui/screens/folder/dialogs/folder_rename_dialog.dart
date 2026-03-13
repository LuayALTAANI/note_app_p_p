import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';

Future<void> showRenameFolderDialog(
  BuildContext context,
  AppDatabase db,
  Folder folder,
) async {
  final controller = TextEditingController(text: folder.name);

  final res = await showDialog<String?>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Rename folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  final name = (res ?? '').trim();
  if (name.isEmpty || name == folder.name) return;

  await db.foldersDao.renameFolder(folder.id, name);
}
