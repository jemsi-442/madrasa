import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'public_shell.dart';
import 'home_photo.dart';

class HomeTeamViewer extends StatefulWidget {
  const HomeTeamViewer({super.key});

  @override
  State<HomeTeamViewer> createState() => _HomeTeamViewerState();
}

class _HomeTeamViewerState extends State<HomeTeamViewer> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor, Size viewport) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 6.0);
    if (target == 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    if (target == current) return;
    final center = viewport.center(Offset.zero);
    final scene = _transform.toScene(center);
    // Keep the same point under the viewport centre when using toolbar zoom.
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, target)
      ..setEntry(1, 1, target)
      ..setEntry(0, 3, center.dx - scene.dx * target)
      ..setEntry(1, 3, center.dy - scene.dy * target);
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Our team',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: publicInk,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close team image',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, imageConstraints) => CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.equal): () =>
                      _zoom(1.5, imageConstraints.biggest),
                  const SingleActivator(
                    LogicalKeyboardKey.equal,
                    shift: true,
                  ): () =>
                      _zoom(1.5, imageConstraints.biggest),
                  const SingleActivator(LogicalKeyboardKey.numpadAdd): () =>
                      _zoom(1.5, imageConstraints.biggest),
                  const SingleActivator(LogicalKeyboardKey.minus): () =>
                      _zoom(1 / 1.5, imageConstraints.biggest),
                  const SingleActivator(
                    LogicalKeyboardKey.numpadSubtract,
                  ): () =>
                      _zoom(1 / 1.5, imageConstraints.biggest),
                  const SingleActivator(LogicalKeyboardKey.digit0): () =>
                      _transform.value = Matrix4.identity(),
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.of(context).pop(),
                },
                child: Focus(
                  autofocus: true,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transform,
                          maxScale: 6,
                          child: Center(
                            child: HomePhoto(
                              asset: 'assets/home/team.webp',
                              aspectRatio: 16 / 9,
                              description:
                                  'Afaq team: Kassim Iddi, Founder; Miraji Hamidu, Co-Founder; Mrs. Ismail and Zuberi Bani, Mentors and Advisors.',
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Material(
                            color: publicCream,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(28),
                            child: ValueListenableBuilder<Matrix4>(
                              valueListenable: _transform,
                              builder: (context, matrix, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Zoom out',
                                    icon: const Icon(Icons.remove),
                                    onPressed:
                                        matrix.getMaxScaleOnAxis() <= 1.001
                                        ? null
                                        : () => _zoom(
                                            1 / 1.5,
                                            imageConstraints.biggest,
                                          ),
                                  ),
                                  IconButton(
                                    tooltip: 'Fit image',
                                    icon: const Icon(Icons.fit_screen),
                                    onPressed: () =>
                                        _transform.value = Matrix4.identity(),
                                  ),
                                  IconButton(
                                    tooltip: 'Zoom in',
                                    icon: const Icon(Icons.add),
                                    onPressed:
                                        matrix.getMaxScaleOnAxis() >= 5.999
                                        ? null
                                        : () => _zoom(
                                            1.5,
                                            imageConstraints.biggest,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
