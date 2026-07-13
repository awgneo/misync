import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:misync/device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../screen.dart';
import '../crc32.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/button.dart';

class FacesScreen extends Screen<FacesModule> {
  const FacesScreen(super.module, {super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends ScreenState<FacesScreen> {
  @override
  Widget buildScreen(BuildContext context, bool connected) {
    // TODO: implement buildScreen
    throw UnimplementedError();
  }
}
