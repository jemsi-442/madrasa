import 'package:flutter/material.dart';
import 'api_client.dart';
import 'automatic_data_updates.dart';

final _queries = Expando<Future<dynamic> Function()>('read queries');
final dataChanges = ValueNotifier<int>(0);
int _writes = 0;
bool get dataWriteInProgress => _writes > 0;

bool liveDataPath(String path) => !RegExp(
  r'/(pdf|csv|export|download|receipt)(/|\?|$)',
  caseSensitive: false,
).hasMatch(path);

Future<dynamic> liveRead(Future<dynamic> Function() read) {
  final future = Future<dynamic>.sync(read);
  _queries[future] = read;
  future.ignore();
  return future;
}

Future<dynamic> dataWrite(Future<dynamic> Function() write) async {
  _writes++;
  dataChanges.value++;
  try {
    return await write();
  } finally {
    _writes--;
    dataChanges.value++;
  }
}

/// Refreshes only read-only result subtrees. Editors remain owned by their page.
class LiveDataBuilder extends StatefulWidget {
  const LiveDataBuilder({
    super.key,
    required this.future,
    required this.builder,
  });
  final Future<dynamic> future;
  final AsyncWidgetBuilder<dynamic> builder;
  @override
  State<LiveDataBuilder> createState() => _LiveDataState();
}

class _LiveDataState extends State<LiveDataBuilder> {
  final content = GlobalKey();
  late final AutomaticDataUpdates updates;
  AsyncSnapshot<dynamic>? latest;
  bool loaded = false, denied = false, stale = false;
  int version = 0;

  // Do not infer that a form is safe just because its text field lost focus.
  // Pause for its entire lifetime, including dropdowns and checkbox editors.
  bool get hasEditor {
    if (context.findAncestorWidgetOfExactType<Form>() != null) return true;
    bool found = false;
    void visit(Element element) {
      final w = element.widget;
      if (w is Form ||
          w is EditableText ||
          w is FormField ||
          w is Checkbox ||
          w is Switch ||
          w is Slider ||
          w is RangeSlider ||
          w is DropdownButton ||
          w is Radio) {
        found = true;
        return;
      }
      element.visitChildElements(visit);
    }

    final root = content.currentContext;
    if (root is Element) root.visitChildElements(visit);
    return found;
  }

  bool get canUpdate =>
      mounted &&
      loaded &&
      !denied &&
      _writes == 0 &&
      _queries[widget.future] != null &&
      ModalRoute.of(context)?.isCurrent != false &&
      !hasEditor;

  @override
  void initState() {
    super.initState();
    updates = AutomaticDataUpdates(canUpdate: () => canUpdate, update: refresh);
    dataChanges.addListener(changed);
  }

  void changed() => updates.tick();
  @override
  void didUpdateWidget(covariant LiveDataBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) {
      version++;
      latest = null;
      loaded = denied = stale = false;
    }
  }

  Future<void> refresh() async {
    final ticket = version, revision = dataChanges.value;
    try {
      final result = await _queries[widget.future]!();
      if (!mounted ||
          ticket != version ||
          revision != dataChanges.value ||
          !canUpdate) {
        return;
      }
      setState(() {
        latest = AsyncSnapshot.withData(ConnectionState.done, result);
        stale = false;
      });
    } catch (e, stack) {
      if (!mounted ||
          ticket != version ||
          revision != dataChanges.value ||
          !canUpdate) {
        return;
      }
      setState(() {
        stale = true;
        // Scoped APIs also return 404 when a guardian link or assignment ends.
        // Unlike a temporary outage, this must not retain the previous record.
        if (e is ApiException && [401, 403, 404, 409].contains(e.statusCode)) {
          denied = true;
          latest = AsyncSnapshot.withError(ConnectionState.done, e, stack);
        }
      });
    }
  }

  @override
  void dispose() {
    dataChanges.removeListener(changed);
    updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: widget.future,
    builder: (context, snapshot) {
      loaded = snapshot.connectionState == ConnectionState.done;
      return Tooltip(
        message: stale && !denied
            ? 'Showing previous data. Updates will retry automatically.'
            : '',
        child: KeyedSubtree(
          key: content,
          child: widget.builder(context, latest ?? snapshot),
        ),
      );
    },
  );
}
