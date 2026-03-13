import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<int?> showFolderColorPicker(
  BuildContext context, {
  required int currentColor,
  required List<int> presets,
}) async {
  Color selected = Color(currentColor);

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Folder color',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          /// 🎡 COLOR WHEEL
          ColorPicker(
            pickerColor: selected,
            onColorChanged: (c) => selected = c,
            enableAlpha: false,
            labelTypes: const [],
          ),

          const SizedBox(height: 12),

          /// 🧱 PRESETS
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Presets',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: presets
                .map(
                  (c) => GestureDetector(
                    onTap: () => selected = Color(c),
                    child: CircleAvatar(
                      backgroundColor: Color(c),
                      radius: 16,
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, selected.value),
                  child: const Text('Save'),
                ),
              ),
            ],
          )
        ],
      ),
    ),
  );
}
