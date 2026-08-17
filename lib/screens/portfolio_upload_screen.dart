import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../main_portfolio.dart';
import '../services/audio_converter.dart';
import '../utils/download_helper.dart';
import '../utils/drop_helper.dart';

class PortfolioUploadScreen extends StatefulWidget {
  const PortfolioUploadScreen({super.key});

  @override
  State<PortfolioUploadScreen> createState() => _PortfolioUploadScreenState();
}

class _PortfolioUploadScreenState extends State<PortfolioUploadScreen> {
  PlatformFile? _selectedFile;
  final GlobalKey _slotKey = GlobalKey();

  bool _isDragOver = false;
  Timer? _dragEndTimer;

  bool _isProcessing = false;
  String? _status;
  bool _success = false;
  String? _targetFormat;
  double? _conversionProgress;

  @override
  void initState() {
    super.initState();
    registerDropListeners(
      onDrop: (x, y, name, bytes) {
        _dragEndTimer?.cancel();
        _dragEndTimer = null;
        if (_isProcessing || !mounted) return;
        setState(() {
          _selectedFile = PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
          );
          _isDragOver = false;
          _status = null;
        });
      },
      onDragMove: (x, y) {
        if (!mounted) return;
        _dragEndTimer?.cancel();
        _dragEndTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _isDragOver = false);
        });
        final ctx = _slotKey.currentContext;
        if (ctx == null) return;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final inside = (box.localToGlobal(Offset.zero) & box.size).contains(
          Offset(x.toDouble(), y.toDouble()),
        );
        if (inside != _isDragOver) setState(() => _isDragOver = inside);
      },
      onDragLeave: () {},
    );
  }

  @override
  void dispose() {
    _dragEndTimer?.cancel();
    unregisterDropListeners();
    super.dispose();
  }

  Future<void> _pickFile() async {
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
        _selectedFile = result.files.first;
        _status = null;
      });
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _status = null;
    });
  }

  Future<void> _process() async {
    final file = _selectedFile;
    if (file == null || file.bytes == null) return;

    setState(() {
      _isProcessing = true;
      _status = null;
      _conversionProgress = null;
      _success = false;
    });

    try {
      final originalExt = file.extension ?? '';
      final targetExt = _targetFormat;
      var bytes = Uint8List.fromList(file.bytes!);

      if (targetExt != null && targetExt != originalExt) {
        setState(() => _status = 'Converting…');
        bytes = await AudioConverter.convert(
          bytes: bytes,
          fromExt: originalExt,
          toExt: targetExt,
          onProgress: (ratio) =>
              setState(() => _conversionProgress = ratio.clamp(0.0, 1.0)),
        );
        setState(() => _conversionProgress = null);
      }

      final outExt = targetExt ?? originalExt;
      final baseName = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;
      downloadBytes(bytes, '$baseName.$outExt');

      setState(() {
        _success = true;
        _status = targetExt != null && targetExt != originalExt
            ? 'Converted and downloaded as $baseName.$outExt'
            : 'Downloaded $baseName.$outExt';
        _selectedFile = null;
      });
    } catch (e) {
      setState(() {
        _success = false;
        _status = 'Failed: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
        _conversionProgress = null;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio/Video Uploader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) => IconButton(
              icon: Icon(
                mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              ),
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => themeNotifier.value = mode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
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

                // ── Description card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.primaryContainer.withValues(alpha: 0.2),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '1. Select or drop an audio or video file.\n'
                        '2. Optionally choose a target format to convert to.\n'
                        '3. Click Convert & Download — your file is processed '
                        'entirely in the browser using FFmpeg and downloaded '
                        'directly to your device. No files are sent to a server.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _FormatChip(
                            label: 'Audio',
                            formats: AudioConverter.audioFormats,
                            icon: Icons.audio_file_outlined,
                            color: cs.primary,
                          ),
                          _FormatChip(
                            label: 'Video',
                            formats: AudioConverter.videoFormats,
                            icon: Icons.video_file_outlined,
                            color: cs.tertiary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── File picker ─────────────────────────────────────────────
                GestureDetector(
                  key: _slotKey,
                  onTap: _isProcessing ? null : _pickFile,
                  child: _FilePickerSlot(
                    file: _selectedFile,
                    isDragOver: _isDragOver,
                    enabled: !_isProcessing,
                    onRemove: _isProcessing ? null : _removeFile,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Format dropdown (web only, with sections) ───────────────
                if (kIsWeb) ...[
                  DropdownMenu<String>(
                    initialSelection: _targetFormat ?? 'original',
                    label: const Text('Convert to format'),
                    leadingIcon: const Icon(Icons.swap_horiz),
                    expandedInsets: EdgeInsets.zero,
                    enabled: !_isProcessing,
                    onSelected: (v) => setState(
                      () => _targetFormat = (v == 'original') ? null : v,
                    ),
                    dropdownMenuEntries: _buildFormatEntries(cs),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Action button / progress ────────────────────────────────
                if (_isProcessing)
                  _StatusCard(
                    message: _status ?? 'Processing…',
                    progress: _conversionProgress,
                  )
                else
                  FilledButton.icon(
                    onPressed: _selectedFile != null ? _process : null,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      _targetFormat != null ? 'Convert & Download' : 'Download',
                    ),
                    style: FilledButton.styleFrom(backgroundColor: cs.primary),
                  ),

                // ── Result banner ───────────────────────────────────────────
                if (_status != null && !_isProcessing) ...[
                  const SizedBox(height: 16),
                  _ResultBanner(message: _status!, success: _success),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuEntry<String>> _buildFormatEntries(ColorScheme cs) {
    final headerStyle = MenuItemButton.styleFrom(
      foregroundColor: cs.outline,
      disabledForegroundColor: cs.outline.withValues(alpha: 0.6),
      textStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );

    return [
      const DropdownMenuEntry(
        value: 'original',
        label: 'Keep original',
        leadingIcon: Icon(Icons.do_not_disturb_alt_outlined, size: 16),
      ),
      // Audio section header
      DropdownMenuEntry(
        value: '__audio_header__',
        label: 'AUDIO FORMATS',
        enabled: false,
        style: headerStyle,
      ),
      ...AudioConverter.audioFormats.map(
        (f) => DropdownMenuEntry(
          value: f,
          label: f.toUpperCase(),
          leadingIcon: const Icon(Icons.audio_file_outlined, size: 16),
        ),
      ),
      // Video section header
      DropdownMenuEntry(
        value: '__video_header__',
        label: 'VIDEO FORMATS',
        enabled: false,
        style: headerStyle,
      ),
      ...AudioConverter.videoFormats.map(
        (f) => DropdownMenuEntry(
          value: f,
          label: f.toUpperCase(),
          leadingIcon: const Icon(Icons.video_file_outlined, size: 16),
        ),
      ),
    ];
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────

class _FormatChip extends StatelessWidget {
  final String label;
  final List<String> formats;
  final IconData icon;
  final Color color;

  const _FormatChip({
    required this.label,
    required this.formats,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ${formats.map((f) => f.toUpperCase()).join(', ')}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerSlot extends StatelessWidget {
  final PlatformFile? file;
  final bool isDragOver;
  final bool enabled;
  final VoidCallback? onRemove;

  const _FilePickerSlot({
    required this.file,
    required this.isDragOver,
    required this.enabled,
    this.onRemove,
  });

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  bool get _isVideo {
    final ext = file?.extension?.toLowerCase() ?? '';
    return AudioConverter.videoFormats.contains(ext);
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

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 187,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
            color: bgColor,
          ),
          child: isDragOver
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 32,
                      color: cs.tertiary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drop file here',
                      style: TextStyle(
                        color: cs.tertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : hasFile
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isVideo
                          ? Icons.video_file_outlined
                          : Icons.audio_file_outlined,
                      size: 32,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        file!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _size(file!.size),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file_outlined,
                      size: 32,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click or drop a media file',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supports audio and video formats',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
        if (hasFile && !isDragOver && onRemove != null)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: cs.surface.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close),
                iconSize: 18,
                tooltip: 'Remove file',
                color: cs.onSurface.withValues(alpha: 0.7),
                onPressed: onRemove,
              ),
            ),
          ),
      ],
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
                  borderRadius: BorderRadius.circular(4),
                )
              : const LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
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
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
