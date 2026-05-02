import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../config/aws_config.dart';
import '../main.dart';
import '../services/audio_converter.dart';
import '../services/s3_service.dart';
import '../utils/download_helper.dart';
import '../utils/drop_helper.dart';
import 'login_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final S3Service _s3;

  // ── Rubric state ──────────────────────────────────────────────────
  Map<String, dynamic> _rubrics = {};
  String? _selectedRubric;
  int _rubricFileCount = 0;
  String _rubricKeyPrefix = '';
  List<PlatformFile?> _selectedFiles = [];
  List<GlobalKey> _slotKeys = [];
  int? _dragOverIndex;
  Timer? _dragEndTimer;

  // ── Upload state ──────────────────────────────────────────────────
  bool _isUploading = false;
  String? _uploadStatus;
  bool _uploadSuccess = false;
  List<({String name, String url})> _uploadedFiles = [];
  DateTime _selectedDate = DateTime.now();
  late final TextEditingController _dateController;
  String? _targetFormat;
  double? _conversionProgress;

  @override
  void initState() {
    super.initState();
    _s3 = S3Service(
      accessKey: AwsConfig.accessKey,
      secretKey: AwsConfig.secretKey,
      region: AwsConfig.region,
      bucket: AwsConfig.bucket,
    );
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _loadRubrics();
    registerDropListeners(
      onDrop: (x, y, name, bytes) {
        _dragEndTimer?.cancel();
        _dragEndTimer = null;
        final index = _hitTestSlots(x, y);
        if (index == null || _isUploading || !mounted) return;
        setState(() {
          _selectedFiles[index] = PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
          );
          _dragOverIndex = null;
          _uploadStatus = null;
        });
      },
      onDragMove: (x, y) {
        if (!mounted) return;
        _dragEndTimer?.cancel();
        _dragEndTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _dragOverIndex = null);
        });
        final index = _hitTestSlots(x, y);
        if (index != _dragOverIndex) setState(() => _dragOverIndex = index);
      },
      onDragLeave: () {},
    );
  }

  @override
  void dispose() {
    _dragEndTimer?.cancel();
    unregisterDropListeners();
    _dateController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _onDateTextChanged(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null &&
          month != null &&
          day != null &&
          year >= 1900 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31) {
        setState(() => _selectedDate = DateTime(year, month, day));
      }
    }
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _dateController.text = _formatDate(picked);
    }
  }

  // ── Rubrics ───────────────────────────────────────────────────────

  Future<void> _loadRubrics() async {
    final data = await rootBundle.loadString('rubrics.json');
    setState(() {
      _rubrics = json.decode(data) as Map<String, dynamic>;
    });
  }

  void _onRubricSelected(String? rubric) {
    if (rubric == null) return;
    final entry = _rubrics[rubric] as List<dynamic>;
    final count = entry[0] as int;
    final s3Url = entry[1] as String;
    final keyPrefix = Uri.parse(s3Url).path.substring(1);
    setState(() {
      _selectedRubric = rubric;
      _rubricFileCount = count;
      _rubricKeyPrefix = keyPrefix;
      _selectedFiles = List.filled(count, null);
      _slotKeys = List.generate(count, (_) => GlobalKey());
      _uploadStatus = null;
      _uploadSuccess = false;
      _uploadedFiles = [];
    });
  }

  int? _hitTestSlots(int clientX, int clientY) {
    final cursor = Offset(clientX.toDouble(), clientY.toDouble());
    for (int i = 0; i < _slotKeys.length; i++) {
      final ctx = _slotKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(cursor)) {
        return i;
      }
    }
    return null;
  }

  // ── Upload ────────────────────────────────────────────────────────

  Future<void> _pickFile(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...AudioConverter.audioFormats,
        ...AudioConverter.videoFormats,
      ],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles[index] = result.files.first;
        _uploadStatus = null;
      });
    }
  }

  bool get _canUpload =>
      _selectedRubric != null && _selectedFiles.any((f) => f != null);

  Future<void> _upload() async {
    final today = DateTime.now();
    if (_selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day) {
      setState(() {
        _uploadSuccess = false;
        _uploadStatus = 'Date cannot be today. Please select a future date.';
      });
      return;
    }

    final slots = _selectedFiles
        .asMap()
        .entries
        .where((e) => e.value != null && e.value!.bytes != null)
        .toList();
    if (slots.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = null;
      _conversionProgress = null;
      _uploadedFiles = [];
    });

    try {
      if (_targetFormat != null) {
        // Conversion requested — convert and download locally, skip S3
        for (final entry in slots) {
          final index = entry.key;
          final file = entry.value!;
          final originalExt = file.extension ?? '';
          final targetExt = _targetFormat!;
          var bytes = Uint8List.fromList(file.bytes!);

          setState(() => _uploadStatus =
              'Converting file ${index + 1} of ${slots.length}…');
          if (targetExt != originalExt) {
            bytes = await AudioConverter.convert(
              bytes: bytes,
              fromExt: originalExt,
              toExt: targetExt,
              onProgress: (ratio) =>
                  setState(() => _conversionProgress = ratio.clamp(0.0, 1.0)),
            );
            setState(() => _conversionProgress = null);
          }

          final s3Name = _s3.buildFileName(
            targetExt,
            _selectedDate,
            keyPrefix: _rubricKeyPrefix,
            fileIndex: _rubricFileCount > 1 ? index + 1 : null,
          );
          downloadBytes(bytes, s3Name.split('/').last);
        }

        setState(() {
          _uploadSuccess = true;
          _uploadStatus = 'Conversion complete — file(s) downloaded';
          _selectedFiles = List.filled(_rubricFileCount, null);
          _uploadedFiles = [];
        });
      } else {
        // No conversion — upload to S3 as normal
        final uploadedKeys = <String>[];
        for (final entry in slots) {
          final index = entry.key;
          final file = entry.value!;
          final originalExt = file.extension ?? '';
          var bytes = Uint8List.fromList(file.bytes!);

          setState(() => _uploadStatus =
              'Uploading file ${index + 1} of ${slots.length}…');
          final s3Name = _s3.buildFileName(
            originalExt,
            _selectedDate,
            keyPrefix: _rubricKeyPrefix,
            fileIndex: _rubricFileCount > 1 ? index + 1 : null,
          );
          await _s3.uploadFile(bytes: bytes, fileName: s3Name);
          uploadedKeys.add(s3Name);
        }

        setState(() => _uploadStatus = 'Generating download links…');
        final links = <({String name, String url})>[];
        for (final key in uploadedKeys) {
          final url = await _s3.presignedDownloadUrl(key);
          links.add((name: key.split('/').last, url: url));
        }

        setState(() {
          _uploadSuccess = true;
          _uploadStatus = 'Upload complete';
          _selectedFiles = List.filled(_rubricFileCount, null);
          _uploadedFiles = links;
        });
      }
    } catch (e) {
      setState(() {
        _uploadSuccess = false;
        _uploadStatus = 'Failed: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
        _conversionProgress = null;
      });
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion Des Rubriques',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) => IconButton(
              icon: Icon(
                mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
              ),
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => themeNotifier.value =
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Rubrique dropdown
                DropdownMenu<String>(
                  label: const Text('Rubrique'),
                  leadingIcon: const Icon(Icons.category_outlined),
                  expandedInsets: EdgeInsets.zero,
                  enabled: !_isUploading && _rubrics.isNotEmpty,
                  initialSelection: _selectedRubric,
                  onSelected: _onRubricSelected,
                  dropdownMenuEntries: _rubrics.keys
                      .map((key) => DropdownMenuEntry(value: key, label: key))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Date field
                TextField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'File date (YYYY-MM-DD)',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range),
                      tooltip: 'Pick date',
                      onPressed: _openDatePicker,
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: _onDateTextChanged,
                ),
                const SizedBox(height: 16),

                // File pickers
                if (_selectedRubric == null)
                  _EmptyRubricHint()
                else
                  for (int i = 0; i < _rubricFileCount; i++) ...[
                    if (_rubricFileCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'File ${i + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: cs.primary),
                        ),
                      ),
                    Container(
                      key: _slotKeys[i],
                      child: _FilePicker(
                        file: _selectedFiles[i],
                        enabled: !_isUploading,
                        isDragOver: _dragOverIndex == i,
                        onTap: () => _pickFile(i),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                // Format dropdown (web only)
                if (kIsWeb)
                  DropdownMenu<String>(
                    initialSelection: _targetFormat ?? 'original',
                    label: const Text('Convert to format'),
                    leadingIcon: const Icon(Icons.swap_horiz),
                    expandedInsets: EdgeInsets.zero,
                    enabled: !_isUploading,
                    onSelected: (v) => setState(
                      () => _targetFormat = (v == 'original') ? null : v,
                    ),
                    dropdownMenuEntries: [
                      const DropdownMenuEntry(
                          value: 'original', label: 'Keep original'),
                      ...AudioConverter.audioFormats.map((f) =>
                          DropdownMenuEntry(
                            value: f,
                            label: f.toUpperCase(),
                            leadingIcon: const Icon(Icons.audio_file_outlined,
                                size: 16),
                          )),
                      ...AudioConverter.videoFormats.map((f) =>
                          DropdownMenuEntry(
                            value: f,
                            label: f.toUpperCase(),
                            leadingIcon: const Icon(Icons.video_file_outlined,
                                size: 16),
                          )),
                    ],
                  ),
                if (kIsWeb) const SizedBox(height: 16),

                // Progress / buttons
                if (_isUploading)
                  _StatusCard(
                    message: _uploadStatus ?? 'Uploading…',
                    progress: _conversionProgress,
                  )
                else
                  FilledButton.icon(
                    onPressed: _canUpload ? _upload : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                    ),
                  ),

                // Result banner
                if (_uploadStatus != null && !_isUploading) ...[
                  const SizedBox(height: 16),
                  _ResultBanner(
                      message: _uploadStatus!, success: _uploadSuccess),
                ],

                // Download links
                if (_uploadedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final f in _uploadedFiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DownloadLink(name: f.name, url: f.url),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _EmptyRubricHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 1.5),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Text(
          'Select a rubrique to begin',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
        ),
      ),
    );
  }
}


class _FilePicker extends StatelessWidget {
  final PlatformFile? file;
  final bool enabled;
  final bool isDragOver;
  final VoidCallback onTap;

  const _FilePicker({
    required this.file,
    required this.enabled,
    required this.onTap,
    this.isDragOver = false,
  });

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = file != null;

    final borderColor = isDragOver
        ? cs.tertiary
        : hasFile
            ? cs.primary
            : cs.outline.withValues(alpha: 0.5);
    final borderWidth = isDragOver ? 2.5 : (hasFile ? 2.0 : 1.5);
    final bgColor = isDragOver
        ? cs.tertiaryContainer.withValues(alpha: 0.2)
        : hasFile
            ? cs.primaryContainer.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          color: bgColor,
        ),
        child: isDragOver
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined,
                      size: 44, color: cs.tertiary),
                  const SizedBox(height: 10),
                  Text('Drop file here',
                      style: TextStyle(
                          color: cs.tertiary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              )
            : hasFile
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 44, color: cs.primary),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          file!.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_size(file!.size),
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: 13)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note,
                          size: 44,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text('Click or drop a media file',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Audio: MP3, WAV, AAC… · Video: MP4, MOV, WEBM…',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.3),
                              fontSize: 12)),
                    ],
                  ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final double? progress;

  const _StatusCard({required this.message, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          progress != null
              ? LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(4))
              : const LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(4))),
          const SizedBox(height: 10),
          Text(message,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  final bool success;

  const _ResultBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF16A34A) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

class _DownloadLink extends StatelessWidget {
  final String name;
  final String url;

  const _DownloadLink({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cs.primaryContainer.withValues(alpha: 0.25),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => openUrl(url),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
