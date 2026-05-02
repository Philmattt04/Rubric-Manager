import 'dart:typed_data';
import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';

class AudioConverter {
  static const List<String> audioFormats = [
    'mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a',
  ];

  static const List<String> videoFormats = [
    'mp4', 'webm', 'mov', 'avi', 'mkv',
  ];

  /// All supported formats (audio + video).
  static const List<String> formats = [...audioFormats, ...videoFormats];

  static const String _corePath =
      'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js';

  static bool _isVideo(String ext) =>
      videoFormats.contains(ext.toLowerCase());

  /// Builds FFmpeg arguments based on the source and target media types.
  static List<String> _buildArgs(
      String input, String output, String fromExt, String toExt) {
    final fromVideo = _isVideo(fromExt);
    final toVideo = _isVideo(toExt);

    if (fromVideo && !toVideo) {
      // Video → Audio: strip the video track, keep audio stream.
      return ['-i', input, '-vn', '-y', output];
    }

    if (!fromVideo && toVideo) {
      // Audio → Video: pair audio with a 640×480 black background.
      final useVpx = toExt == 'webm';
      return [
        '-f', 'lavfi',
        '-i', 'color=black:s=640x480:r=25',
        '-i', input,
        '-c:v', useVpx ? 'libvpx' : 'libx264',
        if (!useVpx) ...const ['-pix_fmt', 'yuv420p'],
        '-c:a', useVpx ? 'libvorbis' : 'aac',
        '-shortest', '-y',
        output,
      ];
    }

    // Audio→Audio or Video→Video: let FFmpeg auto-select codecs.
    return ['-i', input, '-y', output];
  }

  static Future<FFmpeg> _createAndLoad() async {
    final ffmpeg = createFFmpeg(CreateFFmpegParam(
      log: false,
      corePath: _corePath,
      mainName: 'main',
    ));
    await ffmpeg.load();
    return ffmpeg;
  }

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

      final inputFile = 'input.${fromExt.toLowerCase()}';
      final outputFile = 'output.${toExt.toLowerCase()}';

      ffmpeg.writeFile(inputFile, bytes);
      await ffmpeg.run(
          _buildArgs(inputFile, outputFile, fromExt.toLowerCase(), toExt.toLowerCase()));
      return ffmpeg.readFile(outputFile);
    } finally {
      try {
        ffmpeg.exit();
      } catch (_) {}
    }
  }
}
