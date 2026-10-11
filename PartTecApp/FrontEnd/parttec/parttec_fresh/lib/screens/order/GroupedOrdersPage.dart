import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/seller_orders_provider.dart';
import 'SellerOrderDetailsPage.dart';

class GroupedOrdersPage extends StatefulWidget {
  @override
  _GroupedOrdersPageState createState() => _GroupedOrdersPageState();
}

class _GroupedOrdersPageState extends State<GroupedOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, String> statusesMap = {
    'مؤكد': 'طلبات جديدة',
    'موافق عليها': 'موافق عليها',
    'تم التوصيل': 'تم التوصيل',
    'ملغي': 'ملغي',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: statusesMap.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<SellerOrdersProvider>().fetchOrders();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SellerOrdersProvider>().fetchOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'موافق عليها':
        return Colors.green.shade400;
      case 'على الطريق':
        return Colors.blue.shade400;
      case 'مستلمة':
        return Colors.orange.shade400;
      case 'تم التوصيل':
        return Colors.purple.shade400;
      case 'ملغي':
        return Colors.red.shade400;
      case 'مؤكد':
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'موافق عليها':
        return Icons.check_circle;
      case 'على الطريق':
        return Icons.delivery_dining;
      case 'مستلمة':
        return Icons.assignment_turned_in;
      case 'تم التوصيل':
        return Icons.done_all;
      case 'ملغي':
        return Icons.cancel;
      case 'مؤكد':
      default:
        return Icons.fiber_new;
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellerOrdersProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المقدمة من الزبون'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: statusesMap.values.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text(provider.error!))
              : TabBarView(
                  controller: _tabController,
                  children: statusesMap.keys.map((status) {
                    final allOrders = provider.orders;

                    final filtered = status == 'موافق عليها'
                        ? allOrders.where((o) {
                            final s = (o['status'] ?? '').toString();
                            return s == 'موافق عليها' ||
                                s == 'مستلمة' ||
                                s == 'على الطريق';
                          }).toList()
                        : allOrders
                            .where((o) => (o['status'] ?? '') == status)
                            .toList();

                    if (filtered.isEmpty) {
                      return Center(
                          child: Text(
                              'لا توجد طلبات بحالة "${statusesMap[status]}"'));
                    }

                    final Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (final o in filtered) {
                      final c = (o['customer'] as Map?) ?? {};
                      final id = (c['_id'] ?? 'unknown').toString();
                      grouped.putIfAbsent(id, () => []).add(o);
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: grouped.entries.map((entry) {
                        final customerOrders = entry.value;
                        final customer =
                            ((customerOrders.first['customer'] as Map?) ?? {});
                        final name =
                            (customer['name'] ?? 'مستخدم غير معروف').toString();
                        final email = (customer['email'] ?? '').toString();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              child: Icon(Icons.person,
                                  color: Colors.deepPurple.shade700),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(email),
                            children: customerOrders.map((o) {
                              final items = (o['items'] as List?) ?? [];
                              final orderStatus =
                                  (o['status'] ?? '').toString();
                              final firstItem = items.isNotEmpty
                                  ? ((items.first as Map?)?['name']
                                          ?.toString() ??
                                      'قطعة غير معروفة')
                                  : 'بدون عناصر';
                              final total =
                                  ((o['totalAmount'] as num?) ?? 0).toDouble();
                              final createdAt =
                                  (o['createdAt'] ?? '').toString();

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _statusColor(orderStatus)
                                        .withOpacity(0.2),
                                    child: Icon(_statusIcon(orderStatus),
                                        color: _statusColor(orderStatus)),
                                  ),
                                  title: Text(firstItem,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        orderStatus == 'مؤكد'
                                            ? 'طلبات جديدة'
                                            : orderStatus == 'مستلمة'
                                                ? 'تم إيجاد عامل توصيل'
                                                : 'الحالة: $orderStatus',
                                        style: TextStyle(
                                          color: _statusColor(orderStatus),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (createdAt.isNotEmpty)
                                        Text(
                                          _timeAgo(createdAt),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${items.length} عنصر',
                                          style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('${total.toStringAsFixed(2)} ل.س',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SellerOrderDetailsPage(
                                          customerName: name,
                                          orders: [o],
                                        ),
                                      ),
                                    );
                                    context
                                        .read<SellerOrdersProvider>()
                                        .fetchOrders();
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
    );
  }
}
