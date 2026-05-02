import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

JSFunction? _dragOverFn;
JSFunction? _dropFn;

void registerDropListeners({
  required void Function(int x, int y, String name, Uint8List bytes) onDrop,
  required void Function(int x, int y) onDragMove,
  required void Function() onDragLeave,
}) {
  unregisterDropListeners();

  _dragOverFn = ((web.Event event) {
    event.preventDefault();
    final e = event as web.DragEvent;
    onDragMove(e.clientX, e.clientY);
  }).toJS;

  _dropFn = ((web.Event event) {
    event.preventDefault();
    final e = event as web.DragEvent;
    final files = e.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0)!;
    final x = e.clientX;
    final y = e.clientY;
    _readBytes(file).then((bytes) => onDrop(x, y, file.name, bytes));
  }).toJS;

  web.window.addEventListener('dragover', _dragOverFn);
  web.window.addEventListener('drop', _dropFn);
}

void unregisterDropListeners() {
  if (_dragOverFn != null) web.window.removeEventListener('dragover', _dragOverFn);
  if (_dropFn != null) web.window.removeEventListener('drop', _dropFn);
  _dragOverFn = null;
  _dropFn = null;
}

Future<Uint8List> _readBytes(web.File file) {
  final c = Completer<Uint8List>();
  final reader = web.FileReader();
  reader.addEventListener('load', ((web.Event _) {
    c.complete(Uint8List.view((reader.result as JSArrayBuffer).toDart));
  }).toJS);
  reader.addEventListener('error', ((web.Event _) {
    c.completeError('FileReader error');
  }).toJS);
  reader.readAsArrayBuffer(file);
  return c.future;
}
