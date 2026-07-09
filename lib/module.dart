import 'package:flutter/widgets.dart';

abstract class Module {
  Future<void> start();
  Future<void> sync() async {}
}

abstract class TabModule implements Module {
  String get name;
  IconData get icon;
  Widget get screen;
}
