import 'dart:typed_data';
import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';

class AudioConverter {
  static const List<String> formats = ['mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a'];

  static const String _corePath =
      'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js';

  static Future<FFmpeg> _createAndLoad() async {
    final ffmpeg = createFFmpeg(CreateFFmpegParam(
      log: false,
      corePath: _corePath,
      mainName: 'main',
    ));
    await ffmpeg.load();
    return ffmpeg;
  }

  /// Converts [bytes] from [fromExt] to [toExt].
  ///
  /// A fresh FFmpeg instance is created and destroyed for every call so
  /// the wasm "running" flag is always clean between conversions.
  static Future<Uint8List> convert({
    required Uint8List bytes,
    required String fromExt,
    required String toExt,
    void Function(double ratio)? onProgress,
  }) async {
    final ffmpeg = await _createAndLoad();

    try {
      if (onProgress != null) {
        ffmpeg.setProgress((p) => onProgress(p.ratio));
      }

      final inputFile = 'input.$fromExt';
      final outputFile = 'output.$toExt';

      ffmpeg.writeFile(inputFile, bytes);
      await ffmpeg.run(['-i', inputFile, '-y', outputFile]);
      final result = ffmpeg.readFile(outputFile);

      return result;
    } finally {
      // exit() resets the internal JS running flag and frees MEMFS.
      // The browser caches the wasm binary so the next load() is fast.
      try {
        ffmpeg.exit();
      } catch (_) {}
    }
  }
}
