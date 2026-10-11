import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/delivery_orders_provider.dart';
import 'DeliveryMapPage.dart';

class DeliveryOrdersPage extends StatefulWidget {
  const DeliveryOrdersPage({Key? key}) : super(key: key);

  @override
  State<DeliveryOrdersPage> createState() => _DeliveryOrdersPageState();
}

class _DeliveryOrdersPageState extends State<DeliveryOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _tabs = const [
    'طلبات جديدة',
    'مستلمة',
    'على الطريق',
    'تم التوصيل',
    'ملغي'
  ];
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialStatus = _mapTabToStatus(_tabs[_tabController.index]);
      context.read<DeliveryOrdersProvider>().fetchOrders(initialStatus);
    });
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final s = _mapTabToStatus(_tabs[_tabController.index]);
        context.read<DeliveryOrdersProvider>().fetchOrders(s);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _mapTabToStatus(String tab) {
    switch (tab) {
      case 'طلبات جديدة':
        return 'موافق عليها';
      default:
        return tab;
    }
  }

  Future<void> _refreshCurrentTab() async {
    final s = _mapTabToStatus(_tabs[_tabController.index]);
    await context.read<DeliveryOrdersProvider>().fetchOrders(s);
  }

  List<double>? _extractCoordinates(Map order) {
    List? coords = order['coordinates'] as List?;
    coords ??= order['location'] as List?;
    if (coords != null && coords.length >= 2) {
      final lon = double.tryParse(coords[0].toString());
      final lat = double.tryParse(coords[1].toString());
      if (lat != null && lon != null) return [lon, lat];
    }
    return null;
  }

  String _formatCoords(Map order) {
    final c = _extractCoordinates(order);
    if (c == null) return 'الموقع غير متاح';
    return 'إحداثيات: ${c[1].toStringAsFixed(5)}, ${c[0].toStringAsFixed(5)}';
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) {
      return 'منذ ${diff.inDays} يوم';
    } else if (diff.inHours > 0) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inMinutes > 0) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  Future<String?> _fetchAddress(Map order) async {
    final coords = _extractCoordinates(order);
    if (coords == null) return null;
    final lon = coords[0], lat = coords[1];
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=jsonv2',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'parttec-app/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map?;
        return data?['display_name']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<String> _fetchAndCacheAddress(Map order) async {
    final String key = (order['orderId'] ?? order['_id'] ?? '').toString();
    if (_addressCache.containsKey(key)) return _addressCache[key]!;
    final addr = await _fetchAddress(order);
    final fallback = _formatCoords(order);
    final value = (addr != null && addr.isNotEmpty) ? addr : fallback;
    _addressCache[key] = value;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryOrdersProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات التوصيل'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs.map((s) => Tab(text: s)).toList(),
          ),
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null
                ? Center(child: Text(provider.error!))
                : TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final status = _mapTabToStatus(tab);
                      final filtered = provider.orders
                          .where((o) => (o['status'] ?? '') == status)
                          .toList();

                      if (filtered.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () => provider.fetchOrders(status),
                          child: ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child:
                                    Text('لا توجد طلبات بحالة "طلبات جديدة"'),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => provider.fetchOrders(status),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order =
                                filtered[index] as Map<String, dynamic>;
                            final orderNumber = index + 1;
                            return _buildOrderCard(
                                context, order, provider, tab, orderNumber);
                          },
                        ),
                      );
                    }).toList(),
                  ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Map<String, dynamic> order,
    DeliveryOrdersProvider provider,
    String tab,
    int orderNumber,
  ) {
    final status = (order['status'] ?? '').toString();
    final String orderId = (order['orderId'] ?? order['_id'] ?? '').toString();

    final customer = order['customer'] as Map? ?? {};
    final seller = order['seller'] as Map? ?? {};
    final customerName = customer['name']?.toString() ?? '';
    final customerPhone = customer['phoneNumber']?.toString() ?? '';
    final sellerName = seller['name']?.toString() ?? '';
    final sellerPhone = seller['phoneNumber']?.toString() ?? '';

    final coords = _extractCoordinates(order);
    final province = (order['delivery']?['province'] ?? '').toString();

    final part =
        (order['part'] is Map) ? Map<String, dynamic>.from(order['part']) : {};
    final part1 = (order['part1'] is Map)
        ? Map<String, dynamic>.from(order['part1'])
        : {};

    final List<Map<String, dynamic>> partsToShow = [
      if (part.isNotEmpty &&
          (part['name']?.toString() ?? '').trim() != 'قطعة غير معروفة')
        part.cast<String, dynamic>(),
      if (part1.isNotEmpty &&
          (part1['name']?.toString() ?? '').trim() != 'قطعة غير معروفة')
        part1.cast<String, dynamic>(),
    ];

    double partsTotal = 0;
    for (final p in partsToShow) {
      final price = double.tryParse(p['price'].toString());
      if (price != null) partsTotal += price;
    }

    final fee = order['delivery']?['fee'] != null
        ? double.tryParse(order['delivery']!['fee'].toString()) ?? 0
        : 0;
    final grandTotal = partsTotal + fee;
    final createdAt = _timeAgo(order['createdAt']?.toString());

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12, width: 0.8),
      ),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "رقم الطلب: $orderNumber",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("الحالة: $status"),
          ],
        ),
        children: [
          // ✅ لا نعرض بيانات البائع والزبون إذا الحالة "موافق عليها"
          if (status != 'موافق عليها') ...[
            if (sellerName.isNotEmpty) Text('البائع: $sellerName'),
            if (sellerPhone.isNotEmpty) Text('هاتف البائع: $sellerPhone'),
            const SizedBox(height: 8),
            if (customerName.isNotEmpty) Text('الزبون: $customerName'),
            if (customerPhone.isNotEmpty) Text('هاتف الزبون: $customerPhone'),
            if (province.isNotEmpty) Text('المحافظة: $province'),
            if (createdAt.isNotEmpty)
              Text('وقت الطلب: $createdAt',
                  style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
          ],

          if (partsToShow.isNotEmpty) ...[
            const Text("القطع:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...partsToShow.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "${p['name']} - ${p['manufacturer']} - السعر: ${p['price']}",
                    style: const TextStyle(fontSize: 14),
                  ),
                )),
          ],
          const SizedBox(height: 8),

          if (partsToShow.isNotEmpty) ...[
            const Divider(),
            Text("إجمالي سعر القطع: \$${partsTotal.toStringAsFixed(2)}"),
            Text("سعر التوصيل: \$${fee.toStringAsFixed(2)}"),
            Text(
              "المجموع الكلي: \$${grandTotal.toStringAsFixed(2)} 🧾",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Divider(),
          ],

          FutureBuilder<String>(
            future: _fetchAndCacheAddress(order),
            initialData: _formatCoords(order),
            builder: (context, snap) {
              final text = (snap.data == null || snap.data!.isEmpty)
                  ? _formatCoords(order)
                  : snap.data!;
              return Text('الموقع: $text',
                  style: const TextStyle(fontSize: 13));
            },
          ),
          const SizedBox(height: 8),

          if (coords != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryMapPage(
                        lat: coords[1],
                        lng: coords[0],
                        customerName: customerName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text("عرض على الخريطة"),
              ),
            ),

          const SizedBox(height: 12),

          if (tab == 'طلبات جديدة' && status == 'موافق عليها') ...[
            Center(
              child: ElevatedButton(
                onPressed: () {
                  final pageContext = context;
                  double? price;

                  showDialog(
                    context: pageContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('إدخال سعر التوصيل'),
                      content: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'السعر'),
                        onChanged: (value) => price = double.tryParse(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (price != null && price! > 0) {
                              await provider.acceptOrder(
                                  orderId, price!, pageContext);
                              if (!mounted) return;
                              Navigator.pop(dialogContext);
                              await _refreshCurrentTab();
                            }
                          },
                          child: const Text('استلام الطلب'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('استلام الطلب'),
              ),
            ),
          ] else if (status == 'مستلمة') ...[
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await provider.updateStatus(orderId, 'على الطريق',
                      context: context);
                  if (!mounted) return;
                  await _refreshCurrentTab();
                },
                child: const Text('بدء التوصيل'),
              ),
            ),
          ] else if (status == 'على الطريق') ...[
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await provider.updateStatus(orderId, 'تم التوصيل',
                      context: context);
                  if (!mounted) return;
                  await _refreshCurrentTab();
                },
                child: const Text('تم التوصيل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
