import 'dart:typed_data';
import 'package:minio_new/minio.dart';
import '../config/aws_config.dart';

class S3FileInfo {
  final String key;
  final int size;
  final DateTime? lastModified;

  S3FileInfo({required this.key, required this.size, this.lastModified});

  String get filename => key.split('/').last;

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class S3Service {
  final Minio _minio;
  final String bucket;

  S3Service({
    required String accessKey,
    required String secretKey,
    required String region,
    required this.bucket,
  }) : _minio = Minio(
          endPoint: 's3.$region.amazonaws.com',
          accessKey: accessKey,
          secretKey: secretKey,
          region: region,
          useSSL: true,
        );

  String buildFileName(String? extension, DateTime date,
      {String? keyPrefix, int? fileIndex}) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final suffix = fileIndex != null ? '-$fileIndex' : '';
    final name = 'AUDIO$dateStr$suffix';
    final file =
        (extension != null && extension.isNotEmpty) ? '$name.$extension' : name;
    return '${keyPrefix ?? AwsConfig.keyPrefix}$file';
  }

  Future<void> uploadFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final stream = Stream.fromIterable([bytes]);
    await _minio.putObject(bucket, fileName, stream, size: bytes.length);
  }

  Future<List<S3FileInfo>> listFiles() async {
    final result = await _minio.listAllObjects(
      bucket,
      prefix: AwsConfig.keyPrefix,
      recursive: true,
    );
    return result.objects
        .where((o) => o.key != null && o.key != AwsConfig.keyPrefix)
        .map((o) => S3FileInfo(
              key: o.key!,
              size: o.size ?? 0,
              lastModified: o.lastModified,
            ))
        .toList()
      ..sort((a, b) => (b.lastModified ?? DateTime(0))
          .compareTo(a.lastModified ?? DateTime(0)));
  }

  Future<String> presignedDownloadUrl(String key) =>
      _minio.presignedGetObject(bucket, key, expires: 3600);
}
