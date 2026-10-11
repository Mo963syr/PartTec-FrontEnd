import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/purchases_provider.dart';
import '../../utils/session_store.dart';

class UserDeliveredOrdersPage extends StatefulWidget {
  const UserDeliveredOrdersPage({super.key});

  @override
  State<UserDeliveredOrdersPage> createState() =>
      _UserDeliveredOrdersPageState();
}

class _UserDeliveredOrdersPageState extends State<UserDeliveredOrdersPage> {
  String _filter = 'الكل';

  final List<String> _filters = [
    'الكل',
    'اليومي',
    'الأسبوعي',
    'الشهري',
    'السنوي',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final userId = await SessionStore.userId();
      if (userId != null) {
        context.read<PurchasesProvider>().fetchPurchases(userId);
      }
    });
  }

  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> orders, String filter) {
    DateTime now = DateTime.now().toUtc();
    return orders.where((order) {
      final status = order['status'] ?? '';
      if (status != 'تم التوصيل') return false;

      final createdAt = order['createdAt']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;

      final date = DateTime.tryParse(createdAt);
      if (date == null) return false;

      switch (filter) {
        case 'اليومي':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'الأسبوعي':
          final weekday = now.weekday % 7;
          final startOfWeek = DateTime.utc(now.year, now.month, now.day)
              .subtract(Duration(days: weekday));
          final endOfWeek = startOfWeek.add(
              const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          return !date.isBefore(startOfWeek) && !date.isAfter(endOfWeek);
        case 'الشهري':
          return date.year == now.year && date.month == now.month;
        case 'السنوي':
          return date.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchasesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text(provider.error!))
              : _buildPurchases(provider),
    );
  }

  Widget _buildPurchases(PurchasesProvider provider) {
    final filtered = _filterOrders(
        List<Map<String, dynamic>>.from(provider.purchases), _filter);

    double total = filtered.fold(
        0.0, (sum, o) => sum + ((o['totalAmount'] ?? 0).toDouble()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _filter,
            items: _filters
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (val) => setState(() => _filter = val!),
          ),
        ),
        _buildChart(filtered, _filter),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('لا توجد طلبات مكتملة'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    final items = (order['items'] as List?) ?? [];

                    // حساب المجموع الإجمالي في حال عدم وجود totalAmount
                    double orderTotal = (order['totalAmount'] != null)
                        ? ((order['totalAmount'] as num?)?.toDouble() ?? 0)
                        : items.fold<double>(
                            0.0,
                            (s, it) =>
                                s +
                                (((it as Map?)?['total'] as num?)?.toDouble() ??
                                    0.0),
                          );

                    final String orderId =
                        (order['orderId'] ?? order['_id'] ?? '').toString();
                    final supplierName = order['supplier']?['name'] ?? 'مورد';
                    final createdAt = order['createdAt']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(items.length.toString()),
                        ),
                        title: Text('فاتورة #${orderId.substring(0, 6)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplierName.toString()),
                            if (createdAt.isNotEmpty)
                              Text(_formatDate(createdAt)),
                          ],
                        ),
                        trailing: Text('\$${orderTotal.toStringAsFixed(2)}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تفاصيل الفاتورة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('القطعة')),
                                      DataColumn(label: Text('الكمية')),
                                      DataColumn(label: Text('السعر')),
                                      DataColumn(label: Text('الإجمالي')),
                                    ],
                                    rows: items.map<DataRow>((it) {
                                      final name =
                                          (it['name'] ?? 'بدون اسم').toString();
                                      final qty = ((it['quantity'] ?? 0) as num)
                                          .toInt();
                                      final price = ((it['price'] ?? 0) as num)
                                          .toDouble();
                                      final total = it['total'] != null
                                          ? (((it['total'] ?? 0) as num)
                                              .toDouble())
                                          : price * qty;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(name,
                                              overflow: TextOverflow.ellipsis)),
                                          DataCell(Text(qty.toString())),
                                          DataCell(
                                              Text(price.toStringAsFixed(2))),
                                          DataCell(
                                              Text(total.toStringAsFixed(2))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Spacer(),
                                    const Text('المجموع:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(orderTotal.toStringAsFixed(2)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<String?>(
                                  future: _fetchAddressForOrder(order),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text('جاري جلب الموقع...'),
                                        ],
                                      );
                                    }
                                    final addr = snapshot.data;
                                    if (addr != null && addr.isNotEmpty) {
                                      return Text('الموقع: $addr');
                                    }
                                    final coords = _extractCoordinates(order);
                                    if (coords != null) {
                                      return Text(
                                          'إحداثيات الموقع: ${coords[1].toStringAsFixed(5)}, ${coords[0].toStringAsFixed(5)}');
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الطلبات:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
      ],
    );
  }

  /// رسم بياني لإجمالي الطلبات بحسب الفلتر المحدد
  Widget _buildChart(List<Map<String, dynamic>> orders, String filter) {
    if (orders.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text('لا توجد بيانات')));
    }
    final double total = orders.fold(
        0.0, (sum, o) => sum + ((o['totalAmount'] ?? 0).toDouble()));
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      filter,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: total,
                  color: Colors.blue,
                  width: 40,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// تنسيق التاريخ لعرض مبسط
  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// استخراج الإحداثيات من الطلب
  List<double>? _extractCoordinates(Map order) {
    List? coords = order['coordinates'] as List?;
    if (coords == null || coords.length < 2) {
      coords = order['location'] as List?;
    }
    if (coords != null && coords.length >= 2) {
      final lon = double.tryParse(coords[0].toString());
      final lat = double.tryParse(coords[1].toString());
      if (lat != null && lon != null) {
        return [lon, lat];
      }
    }
    return null;
  }

  /// جلب عنوان الموقع عبر Nominatim وفقًا للإحداثيات
  Future<String?> _fetchAddressForOrder(Map order) async {
    final coords = _extractCoordinates(order);
    if (coords == null) return null;
    final lon = coords[0];
    final lat = coords[1];
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=jsonv2');
      final response = await http.get(uri,
          headers: {'User-Agent': 'parttec-app/1.0 (https://example.com)'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map?;
        return data?['display_name']?.toString();
      }
    } catch (_) {
      // تجاهل الأخطاء
    }
    return null;
  }
}
