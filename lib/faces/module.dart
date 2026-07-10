import 'package:flutter/material.dart';
import '../module.dart';
import 'screen.dart';

class FacesModule extends TabModule {
  @override
  String get name => 'faces';

  @override
  IconData get icon => Icons.watch;

  @override
  Widget get screen => const FacesScreen();
  static final FacesModule _instance = FacesModule._();
  static FacesModule get instance => _instance;
  FacesModule._();

  @override
  Future<void> start() async {
    // Background watch face tasks startup logic here if needed
  }

  @override
  Future<void> sync() async {}
}
