import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

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
  static void ensureRegistered() {
    // Web registrant handles FilePickerWeb automatically
  }

  static Future<PickedFileData?> pickExcelOrCsv() async {
    try {
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
    } catch (e) {
      debugPrint('AppFilePicker web error: $e');
      rethrow;
    }
  }
}
