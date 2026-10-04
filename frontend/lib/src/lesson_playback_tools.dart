import 'package:flutter/material.dart';
import 'foundation_ui.dart';

class LessonPlaybackTools extends StatelessWidget {
  const LessonPlaybackTools({
    super.key,
    required this.speed,
    this.onBackward,
    this.onForward,
    this.onSpeed,
  });

  final double speed;
  final VoidCallback? onBackward, onForward;
  final ValueChanged<double>? onSpeed;

  static const speeds = [.5, .75, 1.0, 1.25, 1.5, 2.0];
  static String label(double speed) =>
      '${speed == speed.roundToDouble() ? speed.toInt() : speed}x';

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back 10 seconds',
          onPressed: onBackward,
          color: ink,
          icon: const Icon(Icons.replay_10),
        ),
        Expanded(
          child: Semantics(
            button: true,
            enabled: onSpeed != null,
            child: PopupMenuButton<double>(
              tooltip: 'Playback speed',
              enabled: onSpeed != null,
              initialValue: speed,
              onSelected: onSpeed,
              itemBuilder: (context) => [
                for (final rate in speeds)
                  CheckedPopupMenuItem(
                    key: ValueKey('playback-speed-${label(rate)}'),
                    value: rate,
                    checked: rate == speed,
                    child: Text(rate == 1 ? '1x (Normal)' : label(rate)),
                  ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label(speed),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: onSpeed == null ? muted : ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Forward 10 seconds',
          onPressed: onForward,
          color: ink,
          icon: const Icon(Icons.forward_10),
        ),
      ],
    ),
  );
}
