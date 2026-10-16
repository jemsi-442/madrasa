import 'package:flutter/material.dart';
import 'design_theme.dart';

// Compatibility entry point; all roles use the same control styling.
ThemeData adminTheme(ThemeData base) => afaqControlTheme(base);
