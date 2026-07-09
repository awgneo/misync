import 'package:flutter/material.dart';
import '../module.dart';
import 'screen.dart';

class DebugModule implements TabModule {
  @override
  String get name => 'debug';

  @override
  IconData get icon => Icons.bug_report;

  @override
  Widget get screen => const DebugScreen();
  static final DebugModule _instance = DebugModule._();
  static DebugModule get instance => _instance;
  DebugModule._();

  @override
  Future<void> start() async {
    // Debug logger/observer lifecycle manager initialization if needed
  }

  @override
  Future<void> sync() async {}
}
