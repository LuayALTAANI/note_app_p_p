import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/data/providers.dart';
import 'full_screen_note_editor.dart';

class NotePreviewAndEdit extends ConsumerWidget {
  const NotePreviewAndEdit({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    return InkWell(
      onTap: () async {
        await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenNoteEditor(
              initialText: item.mainData,
              onSave: (text) async {
                await db.itemsDao.updateMainData(item.id, text);
              },
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          item.mainData.isEmpty ? '(Empty note)' : item.mainData,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
