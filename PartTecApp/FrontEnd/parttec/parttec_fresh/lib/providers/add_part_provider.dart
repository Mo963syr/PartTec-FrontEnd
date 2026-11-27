import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../utils/app_settings.dart';
import '../utils/session_store.dart';

class AddPartProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  String _normalizeImageFilename(String rawName, int index) {
    final cleaned = rawName.trim();
    final dotIndex = cleaned.lastIndexOf('.');

    if (dotIndex != -1 && dotIndex < cleaned.length - 1) {
      final ext = cleaned.substring(dotIndex + 1).toLowerCase();
      if (_allowedExtensions.contains(ext)) {
        final base = cleaned
            .substring(0, dotIndex)
            .replaceAll(RegExp(r'[^\w-]'), '_');
        return '${base.isEmpty ? 'part_image_$index' : base}.$ext';
      }
    }
    return 'part_image_$index.jpg';
  }

  MediaType _resolveImageMediaType(String filenameOrPath) {
    final lower = filenameOrPath.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  Future<bool> addPart({
    required String name,
    required String manufacturer,
    required String model,
    required String year,
    required String category,
    required String status,
    required String price,
    String warehouse = 'مجمع القدم',
    File? image,
    List<http.MultipartFile>? images,
    List<File>? imageFiles,
    List<Uint8List>? imageBytesList,
    List<String>? imageNames,
    String? serialNumber,
    String? description,
    int count = 1,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final uid = await SessionStore.userId();
    if (uid == null || uid.isEmpty) {
      errorMessage = 'لم يتم العثور على userId. الرجاء تسجيل الدخول أولاً.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    final uri = Uri.parse('${AppSettings.serverurl}/part/add');
    final request = http.MultipartRequest('POST', uri);

    // 📝 الحقول الأساسية
    request.fields['name'] = name.trim();
    request.fields['manufacturer'] = manufacturer.trim();
    request.fields['model'] = model.trim();
    request.fields['year'] = year.trim();
    request.fields['category'] = category.trim();
    request.fields['status'] = status.trim();
    request.fields['price'] = price.trim();
    request.fields['warehouse'] =
        warehouse.trim().isEmpty ? 'مجمع القدم' : warehouse.trim();
    request.fields['count'] = count.toString();
    request.fields['user'] = uid;

    // 📝 الحقول الاختيارية
    if (serialNumber != null && serialNumber.trim().isNotEmpty) {
      request.fields['serialNumber'] = serialNumber.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }

    // 🖼️ إرفاق مصفوفة الصور تحت المفتاح 'images'
    int attachedCount = 0;

    if (images != null && images.isNotEmpty) {
      for (final file in images) {
        final safeName = _normalizeImageFilename(
          file.filename ?? 'part_image_$attachedCount.jpg',
          attachedCount,
        );
        request.files.add(
          http.MultipartFile(
            'images',
            file.finalize(),
            file.length,
            filename: safeName,
            contentType: _resolveImageMediaType(safeName),
          ),
        );
        attachedCount++;
      }
    } else if (imageBytesList != null && imageBytesList.isNotEmpty) {
      for (var i = 0; i < imageBytesList.length; i++) {
        final bytes = imageBytesList[i];
        final rawHint = (imageNames != null && i < imageNames.length)
            ? imageNames[i]
            : 'part_image_$i.jpg';
        final safeName = _normalizeImageFilename(rawHint, i);
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: safeName,
            contentType: _resolveImageMediaType(safeName),
          ),
        );
        attachedCount++;
      }
    } else if (imageFiles != null && imageFiles.isNotEmpty) {
      for (final file in imageFiles) {
        if (await file.exists()) {
          final safeName = _normalizeImageFilename(
            file.path.split(Platform.pathSeparator).last,
            attachedCount,
          );
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              file.path,
              filename: safeName,
              contentType: _resolveImageMediaType(safeName),
            ),
          );
          attachedCount++;
        }
      }
    } else if (image != null && await image.exists()) {
      final safeName = _normalizeImageFilename(
        image.path.split(Platform.pathSeparator).last,
        0,
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: safeName,
          contentType: _resolveImageMediaType(safeName),
        ),
      );
      attachedCount++;
    }

    if (attachedCount == 0) {
      debugPrint('⚠️ لم يتم إرفاق أي صورة ضمن حقل images');
    } else {
      debugPrint('📸 تم إرفاق $attachedCount صورة ضمن حقل images');
    }

    try {
      final response = await request.send();
      final responseStr = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ تم الإرسال بنجاح: $responseStr');
        return true;
      } else {
        errorMessage = 'فشل الإضافة (${response.statusCode}): $responseStr';
        debugPrint('❌ $errorMessage');
        return false;
      }
    } catch (e) {
      errorMessage = 'خطأ أثناء الإرسال: $e';
      debugPrint('❌ $errorMessage');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}