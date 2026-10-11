import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/part.dart';
import '../utils/app_settings.dart';

class PartsProvider extends ChangeNotifier {
  List<Part> _parts = [];
  bool _isLoading = false;

  List<Part> get parts => _parts;

  bool get isLoading => _isLoading;

  Future<void> fetchParts() async {
    _isLoading = true;
    notifyListeners();

    final uri = Uri.parse('${AppSettings.serverurl}/part/viewPrivateParts');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> list = decoded['parts'] ?? [];
        _parts = list.map((json) => Part.fromJson(json)).toList();
      } else {
        throw Exception('فشل تحميل البيانات');
      }
    } catch (e) {
      print('❌ خطأ أثناء تحميل القطع: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePart(String id) async {
    final uri = Uri.parse('${AppSettings.serverurl}/part/delete/$id');
    try {
      final response = await http.delete(uri);
      if (response.statusCode == 200) {
        _parts.removeWhere((part) => part.id == id);
      } else {
        throw Exception('فشل الحذف');
      }
    } catch (e) {
      print('❌ خطأ أثناء حذف القطعة: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updatePart(String id, Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppSettings.serverurl}/part/update/$id');
    try {
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final updatedJson = decoded['part'] ?? decoded;
        final idx = _parts.indexWhere((p) => p.id == id);
        if (idx != -1) {
          _parts[idx] = Part.fromJson(updatedJson);
          notifyListeners();
        }
        return true;
      } else {
        print('❌ فشل التعديل: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ خطأ أثناء تعديل القطعة: $e');
      return false;
    }
  }
}

class PartRatingProvider with ChangeNotifier {
  double averageRating = 0.0;
  int ratingsCount = 0;
  bool isLoading = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> fetchRating(String partId) async {
    isLoading = true;
    _safeNotify();

    try {
      final url =
          Uri.parse("${AppSettings.serverurl}/part/getPartRatings/$partId");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final d = data['data'];
        averageRating = (d['avgRating'] as num).toDouble();
        ratingsCount = d['ratingsCount'] as int;
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء جلب التقييم: $e");
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }
}
