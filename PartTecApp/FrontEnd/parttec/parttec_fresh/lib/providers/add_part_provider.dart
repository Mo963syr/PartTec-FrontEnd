import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../utils/app_settings.dart';
import '../utils/session_store.dart';

class AddPartProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  Future<bool> addPart({
    required String name,
    required String manufacturer,
    required String model,
    required String year,
    required String category,
    required String status,
    required String price,
    required String warehouse,
    File? image,
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
    request.fields['name'] = name;
    request.fields['manufacturer'] = manufacturer;
    request.fields['model'] = model;
    request.fields['year'] = year;
    request.fields['category'] = category;
    request.fields['status'] = status;
    request.fields['price'] = price;
    request.fields['warehouse'] = warehouse;
    request.fields['count'] = count.toString();
    request.fields['user'] = uid;

    // 📝 الحقول الاختيارية
    if (serialNumber != null && serialNumber.isNotEmpty) {
      request.fields['serialNumber'] = serialNumber;
    }
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    // 🖼️ رفع الصورة
    if (image != null && await image.exists()) {
      // طباعة للمساعدة في التأكد من المسار أثناء الاختبار
      debugPrint('📸 جاري إرفاق الملف: ${image.path}');

      // تحديد الامتداد بشكل دقيق
      final ext = image.path.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // 👈 الاسم المطابق بـ Postman وسيرفر multer
          image.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    } else {
      debugPrint('⚠️ لم يتم العثور على ملف الصورة أو أن قيمته null!');
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
      debugPrint(errorMessage);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}