import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../providers/seller_orders_provider.dart';
import '../../theme/app_theme.dart';

class SellerOrderDetailsPage extends StatefulWidget {
  final String customerName;
  final List<Map<String, dynamic>> orders;

  const SellerOrderDetailsPage({
    Key? key,
    required this.customerName,
    required this.orders,
  }) : super(key: key);

  @override
  State<SellerOrderDetailsPage> createState() => _SellerOrderDetailsPageState();
}

class _SellerOrderDetailsPageState extends State<SellerOrderDetailsPage> {
  String? _address;
  bool _loadingAddress = true;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    final order =
    widget.orders.isNotEmpty ? widget.orders.first : <String, dynamic>{};

    List? coords = order['coordinates'] as List?;
    if (coords == null || coords.length < 2) {
      final loc = order['location'] as List?;
      if (loc != null && loc.length >= 2) coords = loc;
    }
    if (coords != null && coords.length >= 2) {
      final lon = double.tryParse(coords[0].toString());
      final lat = double.tryParse(coords[1].toString());
      if (lat != null && lon != null) {
        try {
          final uri = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=jsonv2');
          final res = await http.get(uri, headers: {
            'User-Agent': 'parttec-app/1.0 (https://example.com)'
          });
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map?;
            setState(() {
              _address = data?['display_name']?.toString();
              _loadingAddress = false;
            });
            return;
          }
        } catch (_) {}
      }
    }
    setState(() {
      _address = null;
      _loadingAddress = false;
    });
  }

  double _numToDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  @override
  Widget build(BuildContext context) {
    final order =
    widget.orders.isNotEmpty ? widget.orders.first : <String, dynamic>{};

    final orderId = (order['_id'] ?? order['orderId'])?.toString() ?? '';
    final status = (order['status'] ?? '').toString();
    final createdAt = _timeAgo((order['createdAt'] ?? '').toString());

    final List<Map<String, dynamic>> items = ((order['items'] as List?) ?? [])
        .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final totalAmount = (order['totalAmount'] != null)
        ? _numToDouble(order['totalAmount'])
        : items.fold<double>(0.0, (s, it) {
      final qty = _numToDouble(it['quantity']).toInt();
      final price = _numToDouble(it['price']);
      final tot =
      it['total'] != null ? _numToDouble(it['total']) : (price * qty);
      return s + tot;
    });

    final shouldShowActions = status == 'قيد التجهيز' || status == 'مؤكد';

    List<dynamic>? coordsList = order['coordinates'] as List?;
    if (coordsList == null || coordsList.length < 2) {
      coordsList = order['location'] as List?;
    }
    double? lat;
    double? lon;
    if (coordsList != null && coordsList.length >= 2) {
      lon = double.tryParse(coordsList[0].toString());
      lat = double.tryParse(coordsList[1].toString());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الزبون: ${widget.customerName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    if (status.isNotEmpty) Text('الحالة الحالية: $status'),
                    if (createdAt.isNotEmpty) Text(createdAt),
                    const SizedBox(height: 10),
                    if (_loadingAddress)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('جاري جلب الموقع...'),
                        ],
                      )
                    else if (_address != null)
                      Text('الموقع: $_address')
                    else if (lat != null && lon != null)
                        Text(
                            'إحداثيات الموقع: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}'),
                  ],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الفاتورة',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('القطعة')),
                          DataColumn(label: Text('الكمية')),
                          DataColumn(label: Text('السعر')),
                          DataColumn(label: Text('الإجمالي')),
                        ],
                        rows: items.map((it) {
                          final name = (it['name'] ?? 'بدون اسم').toString();
                          final qty = _numToDouble(it['quantity']).toInt();
                          final price = _numToDouble(it['price']);
                          final total = it['total'] != null
                              ? _numToDouble(it['total'])
                              : (price * qty);
                          return DataRow(cells: [
                            DataCell(
                                Text(name, overflow: TextOverflow.ellipsis)),
                            DataCell(Text(qty.toString())),
                            DataCell(Text(price.toStringAsFixed(2))),
                            DataCell(Text(total.toStringAsFixed(2))),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Spacer(),
                        const Text(
                          'المجموع:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          totalAmount.toStringAsFixed(2),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (shouldShowActions)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (orderId.isEmpty || orderId == 'null') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('معرف الطلب غير صالح')),
                          );
                          return;
                        }
                        final ok = await context
                            .read<SellerOrdersProvider>()
                            .updateStatus(orderId, 'ملغي');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  ok ? 'تم إلغاء الطلب' : 'فشل إلغاء الطلب')),
                        );
                        if (ok) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (orderId.isEmpty || orderId == 'null') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('معرف الطلب غير صالح')),
                          );
                          return;
                        }
                        final ok = await context
                            .read<SellerOrdersProvider>()
                            .updateStatus(orderId, 'موافق عليها');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(ok
                                  ? 'تمت الموافقة على الطلب'
                                  : 'فشل تحديث الطلب')),
                        );
                        if (ok) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('موافق'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
