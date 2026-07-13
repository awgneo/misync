import 'package:flutter/widgets.dart';
import 'package:misync/screen.dart';
import 'debug/logger.dart';

abstract class Module {
  String get name;
  Future<void> start();
  Future<void> sync() async {}

  late final Logger logger = Logger(name);
}

abstract class TabModule extends Module {
  IconData get icon;
  Screen get screen;
}
