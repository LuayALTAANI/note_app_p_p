import 'dart:io';

import 'package:flutter/material.dart';

class PreviewWidget extends StatelessWidget {
  const PreviewWidget({
    super.key,
    required this.type,
    required this.path,
  });

  final String type;
  final String path;

  @override
  Widget build(BuildContext context) {
    final f = File(path);
    if (!f.existsSync()) {
      return const Center(child: Text('Missing file'));
    }

    switch (type) {
      case 'photo':
        return Image.file(f, fit: BoxFit.cover);
      case 'video':
        return const Center(
          child: Icon(Icons.play_circle, size: 72),
        );
      case 'pdf':
        return const Center(
          child: Icon(Icons.picture_as_pdf, size: 72),
        );
      case 'voice':
        return const Center(
          child: Icon(Icons.audiotrack, size: 72),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
