import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfViewerWidget extends StatelessWidget {
  const PdfViewerWidget({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    if (!file.existsSync()) {
      return const Center(child: Text('PDF unavailable'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PdfViewer.file(
        file.path,
        params: const PdfViewerParams(),
      ),
    );
  }
}