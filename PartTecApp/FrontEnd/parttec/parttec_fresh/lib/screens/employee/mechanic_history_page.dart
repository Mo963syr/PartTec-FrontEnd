import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_settings.dart';
import '../../utils/session_store.dart';

class MechanicHistoryPage extends StatefulWidget {
  const MechanicHistoryPage({super.key});

  @override
  State<MechanicHistoryPage> createState() => _MechanicHistoryPageState();
}

class _MechanicHistoryPageState extends State<MechanicHistoryPage> {
  bool isLoading = true;
  String? errorMsg;
  List<Map<String, dynamic>> orders = [];
  String? _uid;
  double _discountRate = 0.15;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      _uid ??= await SessionStore.userId();
      if (_uid == null || _uid!.isEmpty) {
        setState(() {
          errorMsg = '⚠️ يُرجى تسجيل الدخول أولًا لعرض الطلبات.';
          isLoading = false;
        });
        return;
      }
      final base = AppSettings.serverurl;
      final res1 = await http.get(Uri.parse('$base/order/viewuserorder/$_uid'));
      final res2 = await http.get(Uri.parse('$base/order/viewuserspicificorder/$_uid'));
      final List<Map<String, dynamic>> list = [];
      if (res1.statusCode == 200 && res1.body.isNotEmpty) {
        list.addAll(_parse(res1.body, false));
      }
      if (res2.statusCode == 200 && res2.body.isNotEmpty) {
        list.addAll(_parse(res2.body, true));
      }
      final completed = list.where((o) => (o['status'] ?? '') == 'مكتمل').toList();
      setState(() {
        orders = completed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = 'خطأ أثناء الجلب: $e';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parse(String body, bool specific) {
    final decoded = json.decode(body);
    List raw = [];
    if (specific) {
      if (decoded is Map && decoded['orders'] is List) {
        raw = decoded['orders'];
      }
    } else {
      if (decoded is Map && decoded['orders'] is List) {
        raw = decoded['orders'];
      } else if (decoded is List) {
        raw = decoded;
      }
    }
    return raw.whereType<Map>().map<Map<String, dynamic>>((o) {
      final map = Map<String, dynamic>.from(o as Map);
      if (specific) {
        return {
          'orderId': map['_id'] ?? '',
          'status': map['status'] ?? 'غير محدد',
          'items': [
            {
              'name': map['name'] ?? 'اسم غير معروف',
              'image': map['imageUrl'],
              'price': map['price'],
            }
          ],
        };
      } else {
        final src = (map['cartIds'] is List ? map['cartIds'] : map['items']) as List?;
        final items = (src ?? []).whereType<Map>().map<Map<String, dynamic>>((it) {
          final itm = Map<String, dynamic>.from(it as Map);
          final part = (itm['partId'] ?? itm);
          String? name;
          String? image;
          dynamic price;
          if (part is Map) {
            final pMap = Map<String, dynamic>.from(part);
            name = pMap['name']?.toString();
            image = pMap['imageUrl']?.toString();
            price = pMap['price'];
          }
          return {
            'name': name ?? 'اسم غير معروف',
            'image': image,
            'price': price,
          };
        }).toList();
        return {
          'orderId': map['_id'] ?? '',
          'status': map['status'] ?? 'غير معروف',
          'items': items,
        };
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل الطلبات'),
        ),
        body: isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : errorMsg != null
                ? Center(child: Text('$errorMsg'))
                : orders.isEmpty
                    ? const Center(child: Text('لا توجد طلبات مكتملة حالياً.'))
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: orders.length,
                          itemBuilder: (_, index) {
                            final order = orders[index];
                            final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                            double total = 0;
                            for (final it in items) {
                              final p = it['price'];
                              if (p is num) total += p.toDouble();
                            }
                            final discount = total * _discountRate;
                            final finalTotal = total - discount;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الطلب رقم: ${order['orderId']}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      children: items.map((it) {
                                        return Row(
                                          children: [
                                            it['image'] != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.network(
                                                      it['image'],
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        width: 50,
                                                        height: 50,
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(Icons.broken_image),
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox(width: 50, height: 50),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                it['name'] ?? '',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            Text(
                                              '\$${it['price']}',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        const Text('الإجمالي قبل الخصم:',
                                            style: TextStyle(fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                        Text(
                                          '\$${total.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text('الخصم:',
                                            style: TextStyle(fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                        Text(
                                          '-\$${discount.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text('المجموع بعد الخصم:',
                                            style: TextStyle(fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                        Text(
                                          '\$${finalTotal.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}