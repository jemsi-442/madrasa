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
    this.update,
    this.upload,
  });
  final List<Map<String, dynamic>> courses;
  final PageLoader load;
  final Future<dynamic> Function(String, Map<String, dynamic>)? submit;
  final Future<dynamic> Function(String, Map<String, dynamic>)? update;
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
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Retain the legacy media fixtures in storage, but not in the teaching UI.
    final courses = widget.courses
        .where(
          (course) => !const {
            'afaq-teacher-media-demo',
            'afaq-shared-video-demo',
          }.contains(course['slug']),
        )
        .toList();
    final filtered = courses
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
              final heading = Text(
                'Assigned Courses (${courses.length})',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AfaqDesign.ink,
                ),
              );
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              if (box.maxWidth / textScale.clamp(1.0, 4.0) >= 700) {
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    SizedBox(width: 280, child: searchField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 12),
                  searchField,
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            EmptyRecords(
              search.isEmpty
                  ? 'No courses are assigned to you yet. Ask your madrasa administrator to assign a course.'
                  : 'No courses match your search.',
            )
          else
            for (final c in filtered)
              TeacherCourseCard(
                update: widget.update,
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
}
