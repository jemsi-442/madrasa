import 'package:flutter/material.dart';

const playbackAccent = Color(0xFFFFAA45);
const playbackPanel = Color(0xFF202124);
const playbackMuted = Color(0xFFB6B8BE);

String playbackTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 99999999);
  final minutes = (seconds ~/ 60).toString();
  final tail = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:$tail'
      : '$minutes:$tail';
}

/// One transport bar for native and web playback, independent of the engine.
class LessonPlaybackTools extends StatefulWidget {
  const LessonPlaybackTools({
    super.key,
    required this.speed,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.volume = 1,
    this.looping = false,
    this.focusView = false,
    this.onPlay,
    this.onStop,
    this.onBackward,
    this.onForward,
    this.onSpeed,
    this.onSeek,
    this.onVolume,
    this.onMute,
    this.onLoop,
    this.onFocus,
  });

  final double speed, volume;
  final Duration position, duration;
  final bool playing, looping, focusView;
  final VoidCallback? onPlay,
      onStop,
      onBackward,
      onForward,
      onMute,
      onLoop,
      onFocus;
  final ValueChanged<double>? onSpeed, onVolume;
  final ValueChanged<Duration>? onSeek;

  static const speeds = [.5, .75, 1.0, 1.25, 1.5, 2.0];
  static String label(double speed) =>
      '${speed == speed.roundToDouble() ? speed.toInt() : speed}x';

  @override
  State<LessonPlaybackTools> createState() => _LessonPlaybackToolsState();
}

class _LessonPlaybackToolsState extends State<LessonPlaybackTools> {
  double? scrubbing;

  Widget button(
    String label,
    IconData icon,
    VoidCallback? action, {
    bool selected = false,
  }) => IconButton(
    tooltip: label,
    onPressed: action,
    color: selected ? playbackAccent : Colors.white,
    disabledColor: Colors.white24,
    icon: Icon(icon, size: 21),
  );

  Widget speedMenu() => Semantics(
    button: true,
    enabled: widget.onSpeed != null,
    child: PopupMenuButton<double>(
      tooltip: 'Playback speed',
      enabled: widget.onSpeed != null,
      initialValue: widget.speed,
      onSelected: widget.onSpeed,
      color: playbackPanel,
      itemBuilder: (_) => [
        for (final rate in LessonPlaybackTools.speeds)
          CheckedPopupMenuItem(
            key: ValueKey('playback-speed-${LessonPlaybackTools.label(rate)}'),
            value: rate,
            checked: rate == widget.speed,
            child: Text(
              rate == 1 ? '1x (Normal)' : LessonPlaybackTools.label(rate),
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            LessonPlaybackTools.label(widget.speed),
            style: TextStyle(
              color: widget.onSpeed == null ? Colors.white24 : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final position = (scrubbing ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0);
    return Material(
      color: playbackPanel,
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: playbackAccent,
            surface: playbackPanel,
            onSurface: Colors.white,
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: playbackAccent,
            inactiveTrackColor: Colors.white24,
            thumbColor: playbackAccent,
            overlayColor: playbackAccent.withValues(alpha: .15),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: LayoutBuilder(
            builder: (context, box) {
              final compact =
                  box.maxWidth < 620 ||
                  MediaQuery.textScalerOf(context).scale(13) > 20;
              final transport = Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton.filled(
                    tooltip: widget.playing ? 'Pause' : 'Play',
                    onPressed: widget.onPlay,
                    style: IconButton.styleFrom(
                      backgroundColor: playbackAccent,
                      foregroundColor: const Color(0xFF191919),
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white24,
                    ),
                    icon: Icon(widget.playing ? Icons.pause : Icons.play_arrow),
                  ),
                  button('Stop', Icons.stop, widget.onStop),
                  button('Back 10 seconds', Icons.replay_10, widget.onBackward),
                  button(
                    'Forward 10 seconds',
                    Icons.forward_10,
                    widget.onForward,
                  ),
                ],
              );
              final settings = Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  button(
                    widget.volume == 0 ? 'Unmute' : 'Mute',
                    widget.volume == 0 ? Icons.volume_off : Icons.volume_up,
                    widget.onMute,
                  ),
                  if (!compact)
                    SizedBox(
                      width: 96,
                      child: Slider(
                        key: const ValueKey('playback-volume'),
                        value: widget.volume.clamp(0.0, 1.0),
                        onChanged: widget.onVolume,
                        semanticFormatterCallback: (v) =>
                            'Volume ${(v * 100).round()} percent',
                      ),
                    ),
                  speedMenu(),
                  button(
                    widget.looping ? 'Disable repeat' : 'Repeat',
                    Icons.repeat,
                    widget.onLoop,
                    selected: widget.looping,
                  ),
                  if (widget.onFocus != null)
                    button(
                      widget.focusView ? 'Reduce player' : 'Expand player',
                      widget.focusView
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      widget.onFocus,
                    ),
                ],
              );
              final clock = Text(
                '${playbackTime(Duration(milliseconds: position.round()))} / ${max > 0 ? playbackTime(widget.duration) : '--:--'}',
                textAlign: TextAlign.right,
                style: const TextStyle(color: playbackMuted, fontSize: 12),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          key: const ValueKey('playback-timeline'),
                          value: position,
                          max: max > 0 ? max : 1,
                          onChanged: max > 0 && widget.onSeek != null
                              ? (value) => setState(() => scrubbing = value)
                              : null,
                          onChangeEnd: max > 0 && widget.onSeek != null
                              ? (value) {
                                  widget.onSeek!(
                                    Duration(milliseconds: value.round()),
                                  );
                                  setState(() => scrubbing = null);
                                }
                              : null,
                          semanticFormatterCallback: (v) =>
                              'Seek to ${playbackTime(Duration(milliseconds: v.round()))}',
                        ),
                      ),
                      if (!compact) clock,
                    ],
                  ),
                  if (compact) ...[
                    Align(alignment: Alignment.centerRight, child: clock),
                    transport,
                    settings,
                  ] else
                    Row(children: [transport, const Spacer(), settings]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
