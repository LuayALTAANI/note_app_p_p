// lib/ui/screens/item/item_share.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:note_app_pp/data/app_database.dart';
import 'package:note_app_pp/ui/common/snackbar.dart';
import 'package:note_app_pp/ui/common/video_meta.dart';

Future<void> shareItem(BuildContext context, AppDatabase db, Item item) async {
  if (item.mainType == 'note') {
    final text = item.mainData.trim();
    if (text.isEmpty) {
      showSnack(context, 'Nothing to share');
      return;
    }
    await Share.share(text);
    return;
  }

  // ✅ Separate YouTube vs local (no mixing logic)
  if (item.mainType == 'video' && looksLikeHttpUrl(item.mainData)) {
    await Share.share(item.mainData.trim());
    return;
  }

  final asset = await db.assetsDao.getById(item.mainData);
  if (asset == null || !File(asset.path).existsSync()) {
    showSnack(context, 'Media not found');
    return;
  }
  await Share.shareXFiles([XFile(asset.path)]);
}

Future<void> shareBlock(BuildContext context, AppDatabase db, DetailBlock block) async {
  if (block.type == 'text') {
    final text = block.data.trim();
    if (text.isEmpty) {
      showSnack(context, 'Nothing to share');
      return;
    }
    await Share.share(text);
    return;
  }

  if (block.type == 'video' && block.data.trim().isEmpty) {
    final yt = metaYoutubeUrl(block.meta);
    if (yt == null || yt.trim().isEmpty) {
      showSnack(context, 'Nothing to share');
      return;
    }
    await Share.share(yt.trim());
    return;
  }

  final asset = await db.assetsDao.getById(block.data);
  if (asset == null || !File(asset.path).existsSync()) {
    showSnack(context, 'Media not found');
    return;
  }
  await Share.shareXFiles([XFile(asset.path)]);
}
