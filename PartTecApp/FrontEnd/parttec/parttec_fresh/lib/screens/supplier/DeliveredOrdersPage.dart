import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/seller_orders_provider.dart';
import '../../providers/purchases_provider.dart';
import '../../utils/session_store.dart';
import '../order/SellerOrderDetailsPage.dart';

class DeliveredOrdersPage extends StatefulWidget {
  @override
  State<DeliveredOrdersPage> createState() => _DeliveredOrdersPageState();
}

class _DeliveredOrdersPageState extends State<DeliveredOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _salesFilter = 'الكل';
  String _purchaseFilter = 'الكل';

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
    _tabController = TabController(length: 2, vsync: this);

    Future.microtask(() async {
      final userId = await SessionStore.userId();
      if (userId != null) {
        context.read<SellerOrdersProvider>().fetchOrders();
        context.read<PurchasesProvider>().fetchPurchases(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = context.watch<SellerOrdersProvider>();
    final purchasesProvider = context.watch<PurchasesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('السجل'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المبيعات'),
            Tab(text: 'المشتريات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          salesProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : salesProvider.error != null
                  ? Center(child: Text(salesProvider.error!))
                  : _buildSales(salesProvider),
          purchasesProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : purchasesProvider.error != null
                  ? Center(child: Text(purchasesProvider.error!))
                  : _buildPurchases(purchasesProvider),
        ],
      ),
    );
  }


  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> orders, String filter) {
    DateTime now = DateTime.now().toUtc();

    return orders.where((order) {
      final createdAt = order['createdAt']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;

      final date = DateTime.tryParse(createdAt);
      if (date == null) return false;

      switch (filter) {
        case 'الكل':
          return true;

        case 'اليومي':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;

        case 'الأسبوعي':
          final weekday = now.weekday % 7; // الأحد = 0
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


  Widget _buildChart(List<Map<String, dynamic>> orders, String filter) {
    if (orders.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text("لا توجد بيانات")));
    }

    double total = orders.fold(
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
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSales(SellerOrdersProvider provider) {
    final deliveredOrders = provider.orders
        .where((o) => (o['status'] ?? '') == 'تم التوصيل')
        .map((o) => Map<String, dynamic>.from(o))
        .toList();

    final filteredOrders = _filterOrders(deliveredOrders, _salesFilter);

    double total = filteredOrders.fold(
        0.0, (sum, o) => sum + ((o['totalAmount'] ?? 0).toDouble()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _salesFilter,
            items: _filters
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _salesFilter = val!;
              });
            },
          ),
        ),
        _buildChart(filteredOrders, _salesFilter),
        Expanded(
          child: filteredOrders.isEmpty
              ? const Center(child: Text('لا توجد مبيعات'))
              : ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final items = (order['items'] as List?) ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(items.length.toString()),
                        ),
                        title: Text(
                            ' ${(order['customer']?['name'] ?? '')}'),
                        // subtitle: Text(order['customer']?['name'] ?? 'زبون'),
                        trailing: Text('\$${order['totalAmount']}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerOrderDetailsPage(
                                customerName: order['customer']?['name'] ?? '',
                                orders: [order],
                              ),
                            ),
                          );
                        },
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
              const Text('إجمالي المبيعات:',
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

  Widget _buildPurchases(PurchasesProvider provider) {
    final filteredPurchases =
        _filterOrders(provider.purchases, _purchaseFilter);

    double total = filteredPurchases.fold(
        0.0, (sum, o) => sum + ((o['totalAmount'] ?? 0).toDouble()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _purchaseFilter,
            items: _filters
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _purchaseFilter = val!;
              });
            },
          ),
        ),
        _buildChart(filteredPurchases, _purchaseFilter),
        Expanded(
          child: filteredPurchases.isEmpty
              ? const Center(child: Text('لا توجد مشتريات'))
              : ListView.builder(
            itemCount: filteredPurchases.length,
            itemBuilder: (context, index) {
              final order = filteredPurchases[index];
              final items = (order['items'] as List?) ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(items.length.toString()),
                  ),
                  title: Text(
                    'فاتورة #${(order['orderId'] ?? '').toString().substring(0, (order['orderId'] ?? '').toString().length.clamp(0, 6))}',
                  ),
                  subtitle: Text(order['supplier']?['name'] ?? 'مورد'),
                  trailing: Text('\$${order['totalAmount']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerOrderDetailsPage(
                          customerName: order['supplier']?['name'] ?? 'مورد',
                          orders: [order],
                        ),
                      ),
                    );
                  },
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
              const Text('إجمالي المشتريات:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
