import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import 'screen.dart';

class DebugModule extends TabModule {
  @override
  String get name => 'debug';

  @override
  IconData get icon => Icons.bug_report;

  @override
  late final Screen screen = DebugScreen(this);

  static final DebugModule _module = DebugModule._();
  static DebugModule get module => _module;
  DebugModule._();

  @override
  Future<void> start() async {
    // Debug logger/observer lifecycle manager initialization if needed
  }

  @override
  Future<void> sync() async {}
}
