import 'package:flutter/material.dart';
import 'lesson_upload.dart';
import 'dashboard_components.dart';
import 'design_tokens.dart';

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
    final courses = widget.courses;
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
              if (courses.isEmpty) return heading;
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
              courses.isEmpty
                  ? 'No courses are assigned to you yet. Ask your madrasa administrator to assign a course.'
                  : 'No courses match your search.',
            )
          else
            for (final c in filtered)
              Padding(
                key: ValueKey('teacher-course-row-${c['id']}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE5EF)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final details = Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            color: AfaqDesign.ink,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recordText(c['title']),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AfaqDesign.ink,
                                  ),
                                ),
                                if (recordMap(c['subject'])['name'] !=
                                    null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    recordText(recordMap(c['subject'])['name']),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                      final action = FilledButton.icon(
                        onPressed: () => widget.onOpen(c),
                        icon: const Icon(Icons.library_books_outlined),
                        label: const Text('Manage lessons'),
                      );
                      if (box.maxWidth < 650 ||
                          MediaQuery.textScalerOf(context).scale(16) > 24) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: 16),
                            action,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 24),
                          action,
                        ],
                      );
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
