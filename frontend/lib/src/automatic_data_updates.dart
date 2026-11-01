import 'dart:async';
import 'package:flutter/widgets.dart';

/// Runtime data refresh, independent of development hot reload.
/// The owner handles errors and guards applying responses after disposal.
class AutomaticDataUpdates with WidgetsBindingObserver {
  AutomaticDataUpdates({
    required this.canUpdate,
    required this.update,
    Duration interval = const Duration(seconds: 30),
  }) {
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(interval, (_) => tick());
  }
  final bool Function() canUpdate;
  final Future<void> Function() update;
  Timer? _timer;
  bool _disposed = false, _active = true, _running = false;

  Future<void> tick() async {
    if (_disposed || !_active || _running || !canUpdate()) return;
    _running = true;
    try {
      await update();
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) tick();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
