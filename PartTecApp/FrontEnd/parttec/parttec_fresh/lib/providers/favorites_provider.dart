import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/part.dart';
import '../utils/app_settings.dart';
import '../utils/session_store.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<Part> _favorites = [];

  List<Part> get favorites => List.unmodifiable(_favorites);

  Future<void> toggleFavorite(Part part) async {
    final uid = await SessionStore.userId();
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ لا يوجد userId، الرجاء تسجيل الدخول أولاً.');
      return;
    }

    final exists = _favorites.any((p) => p.id == part.id);
    final endpoint = exists ? 'favorites/remove' : 'favorites/add';

    try {
      final response = await http.post(
        Uri.parse('${AppSettings.serverurl}/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': uid, 'partId': part.id}),
      );

      if (response.statusCode == 200) {
        if (exists) {
          _favorites.removeWhere((p) => p.id == part.id);
        } else {
          _favorites.add(part);
        }
        notifyListeners();
      } else {
        debugPrint(
            '❌ فشل تحديث المفضلة: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('خطأ أثناء تحديث المفضلة: $e');
    }
  }

  bool isFavorite(String id) => _favorites.any((p) => p.id == id);

  Future<void> fetchFavorites() async {
    final uid = await SessionStore.userId();
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ لا يوجد مستخدم مسجل دخول');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppSettings.serverurl}/favorites/view/$uid'),
      );

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final Map<String, dynamic> data =
            (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

        // دعم كلا المفتاحين إذا اختلف عندك في الباك
        final list = (data['favorites'] as List?) ??
            (data['items'] as List?) ??
            <dynamic>[];

        _favorites
          ..clear()
          ..addAll(list.whereType<Map<String, dynamic>>().map(Part.fromJson));
        notifyListeners();
      } else {
        debugPrint(
            'فشل تحميل المفضلة: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('خطأ أثناء تحميل المفضلة: $e');
    }
  }

  /// نادِها عند تسجيل خروج لتصفير الكاش الداخلي
  void resetCachedUser() {
  }
}
