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
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFF00243F)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/home/teacher-media.png',
                        width: 440,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00243F),
                            const Color(0xFF00243F).withValues(alpha: .96),
                            const Color(0xFF00243F).withValues(alpha: .15),
                          ],
                          stops: const [0, .58, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 30,
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) => Row(
                        children: [
                          if (box.maxWidth >= 500) ...[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE8AA13),
                                    Color(0xFFAD7700),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.menu_book_outlined,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'My Courses',
                                    style: TextStyle(
                                      fontSize: box.maxWidth < 500 ? 30 : 40,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Access your assigned courses, modules, lessons and learning resources.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              final tabs = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
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
                ),
              );
              if (box.maxWidth >= 1100) {
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      ),
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
