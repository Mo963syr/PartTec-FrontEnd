import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:parttec/utils/app_settings.dart';
class VinProvider extends ChangeNotifier {
  VinProvider()
      : _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 40),
    ),
  );

  final Dio _dio;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // غيّر هذا الرابط إلى رابط السيرفر عندك
  // مثال محلي:
  // static const String _baseUrl = 'http://192.168.1.10:3001/parttec';
  //
  // أو استخدم dart-define:
  // static const String _baseUrl = String.fromEnvironment(
  //   'VIN_API_BASE_URL',
  //   defaultValue: 'http://192.168.1.10:3001/parttec',
  // );

  Future<String?> extractVinFromImage(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fileName = imageFile.path.split('/').last;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '${AppSettings.serverurl}/vin/extract',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        final data = response.data;
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'فشل استخراج رقم الشاصي')
            : 'فشل استخراج رقم الشاصي';

        throw Exception(message);
      }

      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw Exception('استجابة غير صحيحة من الخادم');
      }

      final vin = data['vin']?.toString();

      if (vin == null || vin.trim().isEmpty) {
        _errorMessage = data['message']?.toString() ?? 'لم يتم العثور على رقم شاسيه واضح';
        return null;
      }

      return vin.trim().toUpperCase();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}