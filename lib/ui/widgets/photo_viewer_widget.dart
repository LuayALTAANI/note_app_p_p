import 'dart:io';
import 'package:flutter/material.dart';

class PhotoViewerWidget extends StatelessWidget {
  const PhotoViewerWidget({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.file(file, fit: BoxFit.contain),
      ),
    );
  }
}