import 'package:flutter/material.dart';
import 'lesson_upload.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';
import 'teacher_course_card.dart';

class TeacherCourseCatalogue extends StatefulWidget {
  const TeacherCourseCatalogue({
    super.key,
    required this.courses,
    required this.load,
    required this.refreshToken,
    required this.onOpen,
    required this.onModule,
    this.apiBaseUrl = '',
    this.submit,
    this.upload,
  });
  final List<Map<String, dynamic>> courses;
  final PageLoader load;
  final Future<dynamic> Function(String, Map<String, dynamic>)? submit;
  final LessonUploader? upload;
  final String apiBaseUrl;
  final int refreshToken;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final void Function(Map<String, dynamic>, Map<String, dynamic>) onModule;
  @override
  State<TeacherCourseCatalogue> createState() => _TeacherCourseCatalogueState();
}

class _TeacherCourseCatalogueState extends State<TeacherCourseCatalogue> {
  String search = '';
  final searchController = TextEditingController();
  int tab = 0;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.courses
        .where(
          (c) =>
              '${c['title'] ?? ''} ${c['summary'] ?? ''} ${recordMap(c['subject'])['name'] ?? ''}'
                  .toLowerCase()
                  .contains(search.trim().toLowerCase()),
        )
        .toList();
    // Responsive controls are reparented at breakpoints. Do not register their
    // transient render objects with the surrounding page-selection delegate.
    // Text fields and the dedicated document readers retain their own selection.
    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final searchField = TextField(
                controller: searchController,
                onChanged: (v) => setState(() => search = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search my courses...',
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            searchController.clear();
                            setState(() => search = '');
                          },
                        ),
                ),
              );
              final tabs = Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _tab(
                    0,
                    Icons.layers_outlined,
                    'Assigned Courses (${widget.courses.length})',
                  ),
                  _tab(1, Icons.play_circle_outline, 'In Progress'),
                  _tab(2, Icons.check_circle_outline, 'Completed'),
                  _tab(3, Icons.grid_view_outlined, 'All My Courses'),
                ],
              );
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              if (box.maxWidth / textScale.clamp(1.0, 4.0) >= 1250) {
                return Row(
                  children: [
                    Expanded(child: tabs),
                    const SizedBox(width: 16),
                    SizedBox(width: 280, child: searchField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tabs,
                  const SizedBox(height: 12),
                  searchField,
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE3E8EF)),
          const SizedBox(height: 20),
          if (tab == 1 || tab == 2)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 32,
                    color: AfaqDesign.blue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Personal course completion is not tracked for teacher assignments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => tab = 0),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('View assigned courses'),
                  ),
                ],
              ),
            )
          else if (filtered.isEmpty)
            EmptyRecords(
              search.isEmpty
                  ? 'No courses are assigned to you yet. Ask your madrasa administrator to assign a course.'
                  : 'No courses match your search.',
            )
          else
            for (final c in filtered)
              TeacherCourseCard(
                upload: widget.upload,
                submit: widget.submit,
                key: ValueKey('teacher-course-card-${c['id']}'),
                course: c,
                load: widget.load,
                apiBaseUrl: widget.apiBaseUrl,
                refreshToken: widget.refreshToken,
                onOpen: () => widget.onOpen(c),
                onModule: (m) => widget.onModule(c, m),
              ),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) => Container(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: tab == index ? AfaqDesign.actionGold : Colors.transparent,
          width: 3,
        ),
      ),
    ),
    child: TextButton.icon(
      onPressed: () => setState(() => tab = index),
      style: TextButton.styleFrom(
        foregroundColor: tab == index ? AfaqDesign.actionGold : AfaqDesign.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
