import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import 'screen.dart';

class FacesModule extends TabModule {
  @override
  String get name => 'faces';

  @override
  IconData get icon => Icons.watch;

  @override
  late final Screen screen = FacesScreen(this);

  static final FacesModule _module = FacesModule._();
  static FacesModule get module => _module;
  FacesModule._();

  @override
  Future<void> start() async {
    // Background watch face tasks startup logic here if needed
  }

  @override
  Future<void> sync() async {}
}
