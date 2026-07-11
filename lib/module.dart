import 'package:flutter/widgets.dart';
import 'debug/logger.dart';

abstract class Module {
  String get name;
  Future<void> start();
  Future<void> sync() async {}
  List<String> get permissions => const [];

  late final Logger logger = Logger(name);
}

abstract class TabModule extends Module {
  IconData get icon;
  Widget get screen;
}
