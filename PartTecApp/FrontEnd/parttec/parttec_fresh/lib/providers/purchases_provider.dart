import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_settings.dart';

class PurchasesProvider with ChangeNotifier {
  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> purchases = [];
  Future<void> fetchPurchases(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final uri = Uri.parse(
          '${AppSettings.serverurl}/order/viewspicificordercompleted/$userId');
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final decoded = json.decode(res.body);

        if (decoded is List) {
          purchases = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (decoded is Map && decoded['orders'] is List) {
          purchases = (decoded['orders'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          purchases = [];
        }
      } else {
        error = "فشل تحميل المشتريات (${res.statusCode})";
        purchases = [];
      }
    } catch (e) {
      error = "خطأ أثناء الجلب: $e";
      purchases = [];
    }

    isLoading = false;
    notifyListeners();
  }

}
