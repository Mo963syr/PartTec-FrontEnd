import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_settings.dart';
import '../utils/session_store.dart';

class DeliveryOrdersProvider with ChangeNotifier {
  String? _driverId;

  bool isLoading = false;
  String? error;

  // آخر تبويب تم تحميله لنستخدمه عند إعادة التحميل بعد تحديث حالة
  String _lastStatus = 'مؤكد';

  final List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);

  Future<void> fetchOrders(String status) async {
    isLoading = true;
    error = null;
    _lastStatus = status;
    notifyListeners();

    try {
      final uid = await SessionStore.userId();
      if (uid == null || uid.isEmpty) {
        throw Exception('لم يتم العثور على معرف موظف التوصيل (driverId).');
      }

      final uri = Uri.parse('${AppSettings.serverurl}/delivery/orders')
          .replace(queryParameters: {
        'status': status,
        'driverId': uid,
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      final bodyText = utf8.decode(response.bodyBytes);
      debugPrint('GET $uri -> ${response.statusCode}');
      debugPrint('📦 Response Body: $bodyText');
      debugPrint(
          'Body (first 200): ${bodyText.substring(0, bodyText.length > 200 ? 200 : bodyText.length)}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $bodyText');
      }

      late final Map<String, dynamic> json;
      try {
        json = jsonDecode(bodyText) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
            'الرد ليس JSON صالحًا. تأكد من أن مسار /delivery/orders فعّال.');
      }

      if (json['success'] != true) {
        throw Exception(json['message'] ?? 'فشل الطلب');
      }

      final List list = (json['orders'] ?? []) as List;

      _orders
        ..clear()
        ..addAll(list.cast<Map<String, dynamic>>());
    } catch (e) {
      error = 'حدث خطأ أثناء تحميل الطلبات: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptOrder(
      String orderId, double fee, BuildContext context) async {
    final driverId = await SessionStore.userId();
    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لم يتم العثور على معرف المندوب")),
      );
      return false;
    }

    final url =
        Uri.parse('${AppSettings.serverurl}/delivery/orders/$orderId/accept');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': driverId,
          'fee': fee,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchOrders('موافق عليها');
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message']?.toString() ?? 'فشل الاستلام')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاستلام: $e')),
      );
    }
    return false;
  }

  Future<void> updateStatus(
    String orderId,
    String newStatus, {
    double? deliveryPrice,
    String? reason,
    BuildContext? context,
  }) async {
    try {
      final uid = await SessionStore.userId();
      if (uid == null || uid.isEmpty) {
        throw Exception('لم يتم العثور على معرف موظف التوصيل (driverId).');
      }

      late final Uri uri;
      late final Map<String, dynamic> body;
      String successMsg = 'تم التحديث';

      switch (newStatus) {
        case 'مستلمة':
          if (deliveryPrice == null || deliveryPrice <= 0) {
            throw Exception('يجب تحديد سعر توصيل صالح لقبول الطلب.');
          }
          uri = Uri.parse(
              '${AppSettings.serverurl}/delivery/orders/$orderId/accept');
          body = {'driverId': uid, 'fee': deliveryPrice};
          successMsg = 'تم استلام الطلب وتحديد سعر التوصيل';
          break;

        case 'على الطريق':
          uri = Uri.parse(
              '${AppSettings.serverurl}/delivery/orders/$orderId/start');
          body = {'driverId': uid};
          successMsg = 'تم بدء التوصيل';
          break;

        case 'تم التوصيل':
          uri = Uri.parse(
              '${AppSettings.serverurl}/delivery/orders/$orderId/complete');
          body = {'driverId': uid};
          successMsg = 'تم التسليم';
          break;

        case 'ملغي':
          uri = Uri.parse(
              '${AppSettings.serverurl}/delivery/orders/$orderId/cancel');
          body = {'driverId': uid, 'reason': reason ?? 'إلغاء من التطبيق'};
          successMsg = 'تم إلغاء الطلب';
          break;

        default:
          // في حال أردت دعم حالات قديمة عبر الـ order/updateOrderStatus
          uri = Uri.parse(
              '${AppSettings.serverurl}/order/updateOrderStatus/$orderId');
          body = {'status': newStatus};
          successMsg = 'تم تحديث حالة الطلب';
      }

      final res = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode(body),
      );

      final bodyText = utf8.decode(res.bodyBytes);
      debugPrint('PUT $uri -> ${res.statusCode}');
      debugPrint(
          'Body (first 200): ${bodyText.substring(0, bodyText.length > 200 ? 200 : bodyText.length)}');

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: $bodyText');
      }

      final data = jsonDecode(bodyText);
      if (data is! Map || data['success'] != true) {
        throw Exception(
            (data is Map ? data['message'] : null) ?? 'فشل تحديث الطلب');
      }

      if (context != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMsg)));
      }

      await fetchOrders(_lastStatus);
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحديث الطلب: $e')),
        );
      }
    }
  }
}
