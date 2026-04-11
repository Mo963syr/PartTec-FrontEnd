import 'dart:io';

// import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/vin_provider.dart';

class VinImageController {
  static const String vinDraftKey = 'vin_draft_value';

  final ImagePicker picker;

  VinImageController({ImagePicker? picker})
      : picker = picker ?? ImagePicker();

  Future<void> saveVinLocally(String vin) async {
    final prefs = await SharedPreferences.getInstance();
    if (vin.isEmpty) {
      await prefs.remove(vinDraftKey);
    } else {
      await prefs.setString(vinDraftKey, vin);
    }
  }

  Future<String?> restoreVinLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(vinDraftKey);
  }

  Future<void> clearSavedVinLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(vinDraftKey);
  }

  Future<XFile?> pickImage(ImageSource source) async {
    return picker.pickImage(
      source: source,
      imageQuality: 92,
    );
  }

  Future<XFile?> recoverLostImage() async {
    final response = await picker.retrieveLostData();

    if (response.isEmpty) return null;

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first;
    }

    if (response.file != null) {
      return response.file!;
    }

    return null;
  }

  Future<String?> extractVinFromFile({
    required XFile file,
    required VinProvider vinProvider,
  }) async {
    return vinProvider.extractVinFromImage(File(file.path));
  }

  Future<void> copyVin(String vin) async {
    await Clipboard.setData(ClipboardData(text: vin));
  }
}