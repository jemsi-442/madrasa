import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AppLayout { website, mobile }

AppLayout resolveAppLayout({bool isWeb = kIsWeb, TargetPlatform? platform}) {
  if (isWeb) return AppLayout.website;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => AppLayout.mobile,
    _ => AppLayout.website,
  };
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({super.key, required this.layout, required super.child});

  final AppLayout layout;

  static bool isMobile(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayoutScope>()?.layout ==
      AppLayout.mobile;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      layout != oldWidget.layout;
}
