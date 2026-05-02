import 'dart:typed_data';

void registerDropListeners({
  required void Function(int x, int y, String name, Uint8List bytes) onDrop,
  required void Function(int x, int y) onDragMove,
  required void Function() onDragLeave,
}) {}

void unregisterDropListeners() {}
