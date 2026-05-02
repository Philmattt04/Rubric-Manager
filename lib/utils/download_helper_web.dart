import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

@JS('window.open')
external void _open(String url, String target);

void openUrl(String url) => _open(url, '_blank');

void downloadBytes(Uint8List bytes, String filename) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
