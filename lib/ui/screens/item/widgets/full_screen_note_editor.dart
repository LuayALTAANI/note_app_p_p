import 'package:flutter/material.dart';

class FullScreenNoteEditor extends StatelessWidget {
  final String initialText;
  final ValueChanged<String>? onSave;

  const FullScreenNoteEditor({
    super.key,
    required this.initialText,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialText);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              onSave?.call(controller.text);
              Navigator.pop(context, controller.text);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          textInputAction: TextInputAction.newline,
        ),
      ),
    );
  }
}
