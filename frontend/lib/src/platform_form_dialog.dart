import 'package:flutter/material.dart';

typedef PlatformFormPresenter =
    Future<bool?> Function(BuildContext context, WidgetBuilder builder);

Future<bool?> showPlatformForm(BuildContext context, WidgetBuilder builder) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: builder,
    );
