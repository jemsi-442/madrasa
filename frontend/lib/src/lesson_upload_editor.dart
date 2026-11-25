import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'lesson_upload.dart';

class LessonUploadEditor extends StatefulWidget {
  const LessonUploadEditor({
    super.key,
    required this.lessonId,
    required this.upload,
    this.pickFile,
  });
  final String lessonId;
  final LessonUploader upload;
  final Future<XFile?> Function()? pickFile;

  @override
  State<LessonUploadEditor> createState() => _LessonUploadEditorState();
}

class _LessonUploadEditorState extends State<LessonUploadEditor> {
  final title = TextEditingController();
  final form = GlobalKey<FormState>();
  XFile? file;
  String? format, error;
  int size = 0;
  bool busy = false, choosing = false, available = false;
  bool readingFile = false;
  bool confirmingClose = false, closing = false;
  String? suggestedTitle;

  void finish([dynamic result]) {
    setState(() => closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> requestClose() async {
    if (busy || choosing || confirmingClose || closing) return;
    if (file == null && title.text.trim().isEmpty && !available) {
      finish();
      return;
    }
    confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this upload?'),
        content: const Text(
          'Your selected file and resource details will not be saved. Stay here to continue uploading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave upload'),
          ),
        ],
      ),
    );
    confirmingClose = false;
    if (mounted && discard == true) finish();
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    if (busy || choosing) return;
    setState(() {
      choosing = true;
      error = null;
    });
    try {
      final chosen =
          await (widget.pickFile?.call() ??
              openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'Lesson resources',
                    extensions: [
                      'pdf',
                      'png',
                      'jpg',
                      'jpeg',
                      'mp4',
                      'mp3',
                      'wav',
                    ],
                    uniformTypeIdentifiers: ['public.data'],
                  ),
                ],
              ));
      if (chosen == null || !mounted) return;
      final kind = lessonFileFormat(chosen.name);
      if (kind == null) {
        setState(() => error = 'Choose a PDF, JPG, PNG, MP4, MP3 or WAV file.');
        return;
      }
      final length = await chosen.length();
      if (!mounted) return;
      if (length == 0 || length > lessonUploadLimitFor(kind)) {
        setState(
          () => error = length == 0
              ? 'This file is empty. Choose a file with content.'
              : 'This ${kind.toUpperCase()} file exceeds the ${lessonUploadLimitFor(kind) ~/ (1024 * 1024)} MB limit. Choose a smaller file.',
        );
        return;
      }
      setState(() {
        file = chosen;
        format = kind;
        size = length;
        final name = chosen.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        final suggestion = name.length > 150 ? name.substring(0, 150) : name;
        // Replace generated titles, but preserve a teacher's custom title.
        if (title.text.trim().isEmpty || title.text == suggestedTitle) {
          title.text = suggestion;
        }
        suggestedTitle = suggestion;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open that file. Choose it again.');
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> save() async {
    if (busy || choosing) return;
    if (!form.currentState!.validate() || file == null) return;
    setState(() {
      busy = true;
      readingFile = true;
      error = null;
    });
    try {
      final bytes = await file!.readAsBytes();
      if (!mounted) return;
      setState(() => readingFile = false);
      if (bytes.isEmpty || bytes.length > lessonUploadLimitFor(format)) {
        throw ApiException(
          'The file must be non-empty and no larger than ${lessonUploadLimitFor(format) ~/ (1024 * 1024)} MB.',
          422,
        );
      }
      final result = await widget.upload(
        widget.lessonId,
        title.text.trim(),
        format!,
        available ? 'FREE' : 'LOCKED',
        bytes,
      );
      if (mounted) finish(result);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = readingFile
              ? 'Could not read the selected file. Choose it again. Your resource title and access setting are kept.'
              : exception is ApiException && exception.statusCode == 401
              ? 'Please sign in again before uploading.'
              : exception is ApiException && exception.statusCode == 403
              ? 'You no longer have permission to add resources to this lesson.'
              : exception is ApiException && exception.statusCode == 413
              ? 'File too large. MP4 video: up to 250 MB. Other files: up to 50 MB.'
              : exception is ApiException && exception.statusCode == 422
              ? 'The file was rejected. Check its format, size and title.'
              : 'Upload could not be confirmed. Your selection is kept. Check lesson resources before retrying to avoid a duplicate.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          readingFile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) requestClose();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Upload lesson resource',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'MP4 video up to 250 MB. Audio, images and PDF up to 50 MB.',
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xffeef4fa),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffd6e2ef)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (format) {
                          'mp4' => Icons.video_library_outlined,
                          'mp3' || 'wav' => Icons.headphones_outlined,
                          'png' || 'jpg' => Icons.image_outlined,
                          'pdf' => Icons.picture_as_pdf_outlined,
                          _ => Icons.upload_file_outlined,
                        },
                        size: 36,
                        color: const Color(0xff173b59),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        file?.name ?? 'Choose your teaching material',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (file != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${format!.toUpperCase()}  /  ${(size / (1024 * 1024)).toStringAsFixed(2)} MB',
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy || choosing ? null : choose,
                        icon: const Icon(Icons.folder_open),
                        label: Text(
                          choosing
                              ? 'Opening files...'
                              : file == null
                              ? 'Choose file'
                              : 'Change file',
                        ),
                      ),
                      if (file != null)
                        TextButton.icon(
                          onPressed: busy || choosing
                              ? null
                              : () => setState(() {
                                  // Clear only the generated title, not the teacher's edits.
                                  if (title.text == suggestedTitle) {
                                    title.clear();
                                  }
                                  file = null;
                                  format = null;
                                  size = 0;
                                  suggestedTitle = null;
                                  error = null;
                                }),
                          icon: const Icon(Icons.close),
                          label: const Text('Remove file'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: title,
                  enabled: !busy,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Resource title',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a resource title.'
                      : null,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make available to eligible learners'),
                  subtitle: const Text(
                    'Off keeps the resource locked. On allows eligible learners only after the course and lesson are published. Uploading does not publish them.',
                  ),
                  value: available,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => available = value),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (busy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            readingFile
                                ? 'Preparing your file...'
                                : 'Uploading your file. Waiting for server confirmation...',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Keep this window open until the upload finishes.',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: busy || choosing || file == null ? null : save,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload resource'),
                    ),
                    TextButton(
                      onPressed: busy || choosing ? null : requestClose,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
