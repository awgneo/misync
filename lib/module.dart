import 'package:flutter/widgets.dart';

abstract class Module {
  Future<void> start();
  Future<void> sync() async {}
  List<String> get permissions => const [];
}

abstract class TabModule extends Module {
  String get name;
  IconData get icon;
  Widget get screen;
}
