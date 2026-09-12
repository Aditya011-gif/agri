import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:windows_file_picker/windows_file_picker.dart';

class PickedFileData {
  final String name;
  final Uint8List bytes;
  final int size;

  const PickedFileData({
    required this.name,
    required this.bytes,
    required this.size,
  });
}

class AppFilePicker {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    try {
      if (!kIsWeb && Platform.isWindows) {
        FilePickerWindows.registerWith();
        _registered = true;
      }
    } catch (e) {
      debugPrint('AppFilePicker registration warning: $e');
    }
  }

  static Future<PickedFileData?> pickExcelOrCsv() async {
    ensureRegistered();
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedFileData(
      name: file.name,
      bytes: bytes,
      size: bytes.length,
    );
  }
}
