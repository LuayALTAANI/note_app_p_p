// ui/screens/item/widgets/main_media_card.dart
import 'package:flutter/material.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'note_preview_edit.dart';
import 'media_preview.dart';

class MainMediaCard extends StatelessWidget {
  const MainMediaCard({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: item.mainType == 'note'
            ? NotePreviewAndEdit(item: item)
            : MediaPreview(
                item: item,
                title: (item.title ?? '').trim().isEmpty
                    ? item.type.toUpperCase()
                    : item.title!.trim(),
              ),
      ),
    );
  }
}
