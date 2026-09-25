import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'admin_forms.dart';
import 'api_client.dart';
import 'attendance_register_page.dart';
import 'dashboard_components.dart';
import 'foundation_ui.dart';
import 'teacher_students_page.dart';
import 'teacher_ui.dart';

class TeacherQuranPage extends StatefulWidget {
  const TeacherQuranPage({
    super.key,
    required this.load,
    required this.submit,
    required this.teacherId,
    this.initialClassId,
    this.initialStudent,
  });
  final PageLoader load;
  final PageSubmitter submit;
  final String teacherId;
  final String? initialClassId;
  final Map<String, dynamic>? initialStudent;
  @override
  State<TeacherQuranPage> createState() => TeacherQuranPageState();
}

class TeacherQuranPageState extends State<TeacherQuranPage> {
  late String classId = widget.initialClassId ?? '';
  late Map<String, dynamic>? student = widget.initialStudent;
  int surah = 67, juz = 29, page = 1, filterEpoch = 0;
  int? from, to;
  bool choosingEnd = false, busy = false;
  String activity = 'MEMORIZATION';
  String? observation, error;
  DateTime date = schoolToday();
  final note = TextEditingController();
  Map<String, dynamic>? pending;
  late Future<dynamic> boot = initialize();
  Future<dynamic>? progress;
  bool get dirty =>
      from != null || note.text.trim().isNotEmpty || pending != null;
  bool get locked => busy || pending != null;
  Future<dynamic> initialize() async {
    final classes = await widget.load('/api/teacher-workspace/classes');
    final catalog = await widget.load('/api/teacher-workspace/quran/catalog');
    return {'classes': classes, 'catalog': catalog};
  }

  @override
  void initState() {
    super.initState();
    if (student != null && classId.isNotEmpty) progress = fetchProgress();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<dynamic> fetchProgress() {
    final request = widget.load(
      '/api/teacher-workspace/quran?${Uri(queryParameters: {'studentId': '${student!['id']}', 'surahId': '$surah', 'page': '$page'}).query}',
    );
    // Filters can still be loading when this request fails.
    request.ignore();
    return request;
  }

  void reloadProgress() => setState(() {
    progress = fetchProgress();
  });
  void clearDraft() {
    from = null;
    to = null;
    choosingEnd = false;
    note.clear();
    observation = null;
    error = null;
    pending = null;
  }

  Future<bool> confirmLeave() async {
    if (busy) return false;
    if (!dirty) return true;
    final leave =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave this learning session?'),
            content: Text(
              pending != null
                  ? 'This save has not been confirmed. Retry with the same details, or leave and check the learning history before recording it again.'
                  : 'Your changes have not been saved. Stay here to finish the session.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay here'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave session'),
              ),
            ],
          ),
        ) ??
        false;
    if (mounted) setState(() => filterEpoch++);
    return leave;
  }

  void refreshPage() => setState(() {
    clearDraft();
    boot = initialize();
    if (student != null) progress = fetchProgress();
  });
  Future<void> changeClass(String value) async {
    if (!await confirmLeave() || !mounted) return;
    setState(() {
      classId = value;
      student = null;
      progress = null;
      clearDraft();
      page = 1;
    });
  }

  Future<void> chooseStudent() async {
    if (!await confirmLeave() || !mounted) return;
    final selected = await pickTeacherStudent(context, widget.load, classId);
    if (selected == null || !mounted) return;
    setState(() {
      student = selected;
      clearDraft();
      page = 1;
      progress = fetchProgress();
    });
  }

  Future<void> changePassage({
    int? nextSurah,
    int? nextJuz,
    required List<Map<String, dynamic>> juzs,
  }) async {
    if (!await confirmLeave() || !mounted) return;
    setState(() {
      juz = nextJuz ?? juz;
      if (nextSurah != null) surah = nextSurah;
      if (juz != 0) {
        final ranges = recordList(
          juzs.firstWhere((j) => j['number'] == juz)['ranges'],
        );
        if (!ranges.any((r) => r['surahId'] == surah)) {
          surah = recordNumber(ranges.first['surahId']).toInt();
        }
      }
      clearDraft();
      page = 1;
      if (student != null) progress = fetchProgress();
    });
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: schoolToday(),
    );
    if (selected != null && mounted) setState(() => date = selected);
  }

  void selectAyah(int ayah) => setState(() {
    if (!choosingEnd || from == null) {
      from = ayah;
      to = ayah;
      choosingEnd = true;
    } else {
      to = math.max(from!, ayah);
      from = math.min(from!, ayah);
      choosingEnd = false;
    }
  });
  Future<void> save() async {
    if (busy ||
        from == null ||
        to == null ||
        observation == null ||
        student == null) {
      return;
    }
    pending ??= {
      'clientId': submissionId(),
      'studentId': '${student!['id']}',
      'classId': classId,
      'surahId': surah,
      'ayahFrom': from,
      'ayahTo': to,
      'activity': activity,
      'observation': observation,
      'learnedOn': attendanceDay(date),
      'note': note.text.trim(),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit('/api/teacher-workspace/quran/sessions', pending!);
      if (!mounted) return;
      setState(() {
        clearDraft();
        page = 1;
        progress = fetchProgress();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Learning session saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiException && [403, 404, 422].contains(e.statusCode)) {
          pending = null;
          error = e.statusCode == 422
              ? 'Check the session date and selected ayahs, then try again.'
              : 'This student is no longer available to your account. Refresh your class list.';
        } else {
          error =
              'We could not confirm this save. Keep this page open and retry with the same details.';
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> voidSession(Map<String, dynamic> session) async {
    if (!await confirmLeave() || !mounted) return;
    final saved = await showAdminForm(
      context,
      title: 'Correct a learning record',
      note:
          'The original entry will stay in the history as voided. You can then record the correct session.',
      saveLabel: 'Void this entry',
      fields: const [AdminField('reason', 'Reason for correction')],
      onSave: (values) async {
        await widget.submit(
          '/api/teacher-workspace/quran/sessions/${session['id']}/void',
          values,
        );
      },
    );
    if (saved && mounted) {
      setState(() {
        clearDraft();
        progress = fetchProgress();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PageResult(
    future: boot,
    onRetry: () => setState(() {
      boot = initialize();
    }),
    builder: (value) {
      final data = recordMap(value), catalog = recordMap(data['catalog']);
      final classes = recordList(data['classes']),
          chapters = recordList(catalog['chapters']),
          juzs = recordList(catalog['juzs']);
      final chapter = chapters.firstWhere((c) => c['id'] == surah);
      final ranges = juz == 0
          ? <Map<String, dynamic>>[]
          : recordList(juzs.firstWhere((j) => j['number'] == juz)['ranges']);
      final visible = chapters
          .where((c) => juz == 0 || ranges.any((r) => r['surahId'] == c['id']))
          .toList();
      final range = ranges.where((r) => r['surahId'] == surah).firstOrNull;
      final rangeFrom = range == null ? 1 : recordNumber(range['from']).toInt();
      final rangeTo = recordNumber(
        range?['to'] ?? chapter['ayahCount'],
      ).toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfacePanel(
            child: LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 950
                    ? 4
                    : box.maxWidth >= 560
                    ? 2
                    : 1;
                final width = (box.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: [
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('quran-class-$classId-$filterEpoch'),
                        isExpanded: true,
                        initialValue:
                            classes.any((c) => '${c['id']}' == classId)
                            ? classId
                            : null,
                        decoration: const InputDecoration(labelText: 'Class'),
                        hint: const Text('Choose a class'),
                        items: [
                          for (final c in classes)
                            DropdownMenuItem(
                              value: '${c['id']}',
                              child: Text('${c['name']}'),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) {
                                if (v != null) changeClass(v);
                              },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54),
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: classId.isEmpty || locked
                            ? null
                            : chooseStudent,
                        icon: const Icon(Icons.person_outline, size: 18),
                        label: Text(
                          student == null
                              ? 'Choose a student'
                              : '${student!['fullName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('quran-juz-$juz-$filterEpoch'),
                        initialValue: juz,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Juz'),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('All juz'),
                          ),
                          for (final j in juzs)
                            DropdownMenuItem(
                              value: recordNumber(j['number']).toInt(),
                              child: Text('Juz ${j['number']}'),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) {
                                if (v != null) {
                                  changePassage(nextJuz: v, juzs: juzs);
                                }
                              },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('quran-surah-$surah-$juz-$filterEpoch'),
                        initialValue: surah,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Surah'),
                        items: [
                          for (final c in visible)
                            DropdownMenuItem(
                              value: recordNumber(c['id']).toInt(),
                              child: Text(
                                '${c['id']} - ${c['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (v) {
                                if (v != null) {
                                  changePassage(nextSurah: v, juzs: juzs);
                                }
                              },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          if (progress == null)
            const SurfacePanel(
              child: EmptyRecords(
                'Choose a class and student to open their learning record.',
              ),
            )
          else
            PageResult(
              future: progress!,
              onRetry: reloadProgress,
              builder: (value) {
                final record = recordMap(value),
                    learner = recordMap(record['student']);
                final memorised = (record['memorisedAyahs'] as List? ?? [])
                    .map((v) => recordNumber(v).toInt())
                    .toSet();
                return PanelColumns(
                  firstFlex: 2,
                  first: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurfacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PanelHeading(
                              'Select ayahs',
                              subtitle:
                                  'Tap a start and end ayah to choose a range.',
                            ),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${chapter['name']}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Surah $surah | ${chapter['ayahCount']} ayahs${juz == 0 ? '' : ' | Juz $juz: $rangeFrom-$rangeTo'}',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                TeacherTag(
                                  '${memorised.length} / ${chapter['ayahCount']} memorised',
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, box) {
                                final columns = math.max(
                                  3,
                                  math.min(10, (box.maxWidth / 56).floor()),
                                );
                                final width =
                                    (box.maxWidth - (columns - 1) * 8) /
                                    columns;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (
                                      var ayah = rangeFrom;
                                      ayah <= rangeTo;
                                      ayah++
                                    )
                                      SizedBox(
                                        width: width,
                                        height: 46,
                                        child: Semantics(
                                          selected:
                                              from != null &&
                                              ayah >= from! &&
                                              ayah <= to!,
                                          label:
                                              'Ayah $ayah${memorised.contains(ayah) ? ', previously memorised' : ''}',
                                          child: OutlinedButton(
                                            key: ValueKey('ayah-$ayah'),
                                            onPressed: locked
                                                ? null
                                                : () => selectAyah(ayah),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              foregroundColor:
                                                  from != null &&
                                                      ayah >= from! &&
                                                      ayah <= to!
                                                  ? Colors.white
                                                  : memorised.contains(ayah)
                                                  ? forest
                                                  : muted,
                                              backgroundColor:
                                                  from != null &&
                                                      ayah >= from! &&
                                                      ayah <= to!
                                                  ? ink
                                                  : memorised.contains(ayah)
                                                  ? const Color(0xFFE5F3ED)
                                                  : const Color(0xFFF3F5F8),
                                              side: BorderSide(
                                                color: memorised.contains(ayah)
                                                    ? const Color(0xFFCCE6DB)
                                                    : line,
                                              ),
                                            ),
                                            child: Text('$ayah'),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                for (final (label, color) in [
                                  ('Previously memorised', forest),
                                  ('Selected now', ink),
                                  ('Not recorded as memorised', muted),
                                ])
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, color: color, size: 8),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const TeacherNotice(
                              'Reading, memorisation and revision are recorded separately. Memorisation counts here only when observed as independent.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SurfacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PanelHeading(
                              'Learning history',
                              subtitle:
                                  'Sessions for the selected surah. Corrections remain visible in this history.',
                            ),
                            LearningHistory(
                              recordList(record['sessions']),
                              teacherId: widget.teacherId,
                              onVoid: locked ? null : voidSession,
                            ),
                            DirectoryPager(
                              meta: recordMap(record['meta']),
                              onPage: (v) async {
                                if (!await confirmLeave() || !mounted) return;
                                setState(() {
                                  clearDraft();
                                  page = v;
                                  progress = fetchProgress();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  second: SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PanelHeading('Record a learning session'),
                        StudentIdentity(
                          learner,
                          subtitle:
                              '${recordMap(learner['currentClass'])['name']} | ${learner['admissionNo']}',
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Activity',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in learningActivities.entries)
                              ChoiceChip(
                                label: Text(
                                  entry.value,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: activity == entry.key,
                                onSelected: locked
                                    ? null
                                    : (_) =>
                                          setState(() => activity = entry.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('from-$from-$rangeFrom'),
                                initialValue: from,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'From ayah',
                                ),
                                items: [
                                  for (var n = rangeFrom; n <= rangeTo; n++)
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text('$n'),
                                    ),
                                ],
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() {
                                        from = v;
                                        to = math.max(v!, to ?? v);
                                        choosingEnd = false;
                                      }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('to-$to-$from'),
                                initialValue: to,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'To ayah',
                                ),
                                items: [
                                  for (
                                    var n = from ?? rangeFrom;
                                    n <= rangeTo;
                                    n++
                                  )
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text('$n'),
                                    ),
                                ],
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() {
                                        to = v;
                                        from ??= v;
                                        choosingEnd = false;
                                      }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          key: ValueKey('observation-$observation'),
                          initialValue: observation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Teacher observation',
                          ),
                          items: [
                            for (final entry in learningObservations.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: locked
                              ? null
                              : (v) => setState(() => observation = v),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: locked ? null : pickDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                          ),
                          label: Text(shortDate(attendanceDay(date))),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: note,
                          enabled: !locked,
                          maxLength: 1000,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Optional note',
                            hintText:
                                'Add a brief observation for this session...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (error != null) ...[
                          TeacherNotice(error!, warning: true),
                          const SizedBox(height: 16),
                        ],
                        const TeacherNotice(
                          'Keep this page open until your save is confirmed. An internet connection is required.',
                          warning: true,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: busy || from == null || observation == null
                              ? null
                              : save,
                          icon: busy
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            busy
                                ? 'Saving...'
                                : pending != null
                                ? 'Retry save'
                                : 'Save progress',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
