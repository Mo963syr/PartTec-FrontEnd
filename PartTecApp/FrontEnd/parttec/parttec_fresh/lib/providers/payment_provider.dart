import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentProvider with ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  String baseUrl = "https://egate-t.fatora.me/api"; // Test Environment
  String? terminalId = "99990001"; // هاد بتاخده من Fatora بعد التسجيل
  String? username = "your_username"; // يجيك من Fatora
  String? password = "your_password"; // يجيك من Fatora

  /// إنشاء دفعة جديدة
  Future<Map<String, dynamic>?> createPayment({
    required int amount,
    required String callbackUrl,
    required String triggerUrl,
    String lang = "ar",
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse("$baseUrl/create-payment");

      final body = {
        "lang": lang,
        "terminalId": terminalId,
        "amount": amount,
        "callbackURL": callbackUrl,
        "triggerURL": triggerUrl,
      };

      final response = await http.post(
        url,
        headers: {
          "Authorization":
              "Basic ${base64Encode(utf8.encode("$username:$password"))}",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (data["ErrorCode"] == 0) {
        return data["Data"];
      } else {
        errorMessage = data["ErrorMessage"];
        return null;
      }
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// التحقق من حالة الدفع
  Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    try {
      final url = Uri.parse("$baseUrl/get-payment-status/$paymentId");

      final response = await http.get(
        url,
        headers: {
          "Authorization":
              "Basic ${base64Encode(utf8.encode("$username:$password"))}",
        },
      );

      final data = jsonDecode(response.body);
      if (data["ErrorCode"] == 0) {
        return data["Data"];
      } else {
        errorMessage = data["ErrorMessage"];
        return null;
      }
    } catch (e) {
      errorMessage = e.toString();
      return null;
    }
  }

  /// إلغاء دفعة (Reversal)
  Future<bool> cancelPayment(String paymentId) async {
    try {
      final url = Uri.parse("$baseUrl/cancel-payment");

      final body = {"lang": "ar", "payment_id": paymentId};

      final response = await http.post(
        url,
        headers: {
          "Authorization":
              "Basic ${base64Encode(utf8.encode("$username:$password"))}",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return data["ErrorCode"] == 0;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }
}
