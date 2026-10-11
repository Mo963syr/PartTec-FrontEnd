import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_settings.dart';
import '../../utils/session_store.dart';
import '../../providers/order_provider.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("طلباتي"),
        ),
        body: const _MyOrdersView(),
      ),
    );
  }
}

class _MyOrdersView extends StatefulWidget {
  const _MyOrdersView();

  @override
  State<_MyOrdersView> createState() => _MyOrdersViewState();
}

class _MyOrdersViewState extends State<_MyOrdersView> {
  bool isLoading = true;
  List<Map<String, dynamic>> grouped = [];
  String? errorMsg;

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
      final uid = await SessionStore.userId();
      final role = await SessionStore.role();
      print('🔑 uid: $uid');
      print('🎭 role: $role');
      if (uid == null || uid.isEmpty) {
        setState(() {
          errorMsg = '⚠️ يُرجى تسجيل الدخول أولًا لعرض الطلبات.';
          isLoading = false;
        });
        return;
      }

      final base = AppSettings.serverurl;
      http.Response? res1;
      http.Response? res2;

      // if (role == 'user') {
        res1 = await http.get(Uri.parse('$base/order/viewuserorder/$uid'));
        res2 = await http.get(Uri.parse('$base/order/viewuserspicificorder/$uid'));
      // } else if (role == 'seller') {
      //   res2 = await http.get(Uri.parse('$base/order/viewuserspicificorder/$uid'));
      // }

      final List<Map<String, dynamic>> list = [];

      if (res1 != null && res1.statusCode == 200 && res1.body.isNotEmpty) {
        list.addAll(_parse(res1.body, false));
      }
      if (res2 != null && res2.statusCode == 200 && res2.body.isNotEmpty) {
        list.addAll(_parse(res2.body, true));
      }

      if (list.isEmpty &&
          ((res1 != null && res1.statusCode != 200) ||
              (res2 != null && res2.statusCode != 200))) {
        errorMsg =
        'فشل تحميل الطلبات (${res1?.statusCode ?? '-'}/${res2?.statusCode ?? '-'})';
      }

      setState(() {
        grouped = list;
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
        final rawStatus = (map['status'] ?? 'غير محدد').toString();
        final userStatus = rawStatus == 'مؤكد' ? 'قيد المعالجة' : rawStatus;
        return {
          'orderId': map['_id'] ?? '',
          'status': userStatus,
          'expanded': false,
          'items': [
            {
              'name': map['name'] ?? 'اسم غير معروف',
              'image': map['imageUrl'],
              'price': map['price'],
              'status': userStatus,
              'canCancel': false,
              'cartId': map['_id'] ?? '',
            }
          ],
        };
      } else {
        final src =
        (map['cartIds'] is List ? map['cartIds'] : map['items']) as List?;
        final items =
        (src ?? []).whereType<Map>().map<Map<String, dynamic>>((it) {
          final itm = Map<String, dynamic>.from(it as Map);
          final part = (itm['partId'] ?? itm);
          String? name, image;
          dynamic price;
          if (part is Map) {
            final pMap = Map<String, dynamic>.from(part);
            name = pMap['name']?.toString();
            image = pMap['imageUrl']?.toString();
            price = pMap['price'];
          }
          final rawItemStatus =
          (itm['status'] ?? map['status'] ?? 'غير متوفر').toString();
          final userItemStatus =
          rawItemStatus == 'مؤكد' ? 'قيد المعالجة' : rawItemStatus;
          return {
            'name': name ?? 'اسم غير معروف',
            'image': image,
            'price': price,
            'status': userItemStatus,
            'canCancel': (map['status'] == 'قيد التجهيز'),
            'cartId': itm['_id'] ?? '',
          };
        }).toList();

        final rawOrderStatus = (map['status'] ?? 'غير معروف').toString();
        final userOrderStatus =
        rawOrderStatus == 'مؤكد' ? 'قيد المعالجة' : rawOrderStatus;

        return {
          'orderId': map['_id'] ?? '',
          'status': userOrderStatus,
          'expanded': false,
          'items': items,
        };
      }
    }).toList();
  }

  Future<void> _cancel(String cartId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم طلب إلغاء الطلب $cartId (تجريبي)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (errorMsg != null && grouped.isEmpty) {
      return Center(child: Text('$errorMsg'));
    }
    if (grouped.isEmpty) {
      return const Center(child: Text('لا توجد طلبات لعرضها حاليًا.'));
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: grouped.length,
        itemBuilder: (_, index) {
          final order = grouped[index];
          final expanded = (order['expanded'] as bool?) ?? false;
          final status = order['status'] as String? ?? 'غير معروف';
          final items =
              (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          final orderId = (order['orderId'] ?? '').toString();

          return _OrderCard(
            orderId: orderId,
            index: index,
            status: status,
            expanded: expanded,
            items: items,
            onToggle: (v) => setState(() => order['expanded'] = v),
            onCancel: _cancel,
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final int index;
  final String status;
  final bool expanded;
  final List<Map<String, dynamic>> items;
  final ValueChanged<bool> onToggle;
  final void Function(String cartId) onCancel;

  const _OrderCard({
    required this.orderId,
    required this.index,
    required this.status,
    required this.expanded,
    required this.items,
    required this.onToggle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text("الطلب رقم ${index + 1} - $status"),
        initiallyExpanded: expanded,
        onExpansionChanged: (open) {
          onToggle(open);
          if (open && orderId.isNotEmpty) {
            context.read<OrderProvider>().fetchOffersForOrder(orderId);
          }
        },
        children: [
          ...items.map((item) => ListTile(
            leading: (item['image'] != null &&
                item['image'].toString().isNotEmpty)
                ? Image.network(
              item['image'],
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported),
            )
                : const Icon(Icons.image_not_supported),
            title: Text(item['name']),
            subtitle: Text("السعر: ${item['price'] ?? 'غير محدد'}"),
            trailing: item['canCancel'] == true
                ? IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: () => onCancel(item['cartId']),
            )
                : null,
          )),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Consumer<OrderProvider>(
              builder: (_, prov, __) {
                final loading = prov.isLoadingOffers(orderId);
                final offers = prov.offersFor(orderId);

                if (loading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (offers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(child: Text('لا توجد عروض حالياً لهذا الطلب')),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                      child: Text(
                        "العروض المتاحة:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    ...offers.map((offer) {
                      final offerId = (offer['_id'] ??
                          offer['id'] ??
                          offer['offerId'] ??
                          '')
                          .toString();
                      final desc = (offer['description'] ?? 'عرض').toString();
                      final price = (offer['price'] ?? 'غير محدد').toString();
                      final image = (offer['imageUrl'] ?? '').toString();
                      final supplier =
                      (offer['supplierName'] ?? 'مورد').toString();

                      return ListTile(
                        leading: image.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            image,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.local_offer,
                                color: AppColors.primary),
                          ),
                        )
                            : const Icon(Icons.local_offer,
                            color: AppColors.primary),
                        title: Text(desc),
                        subtitle: Text('السعر: $price — $supplier'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final ok = await context
                                .read<OrderProvider>()
                                .addOfferToCart(offerId, orderId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? '✅ تمت إضافة العرض إلى السلة'
                                  : (context
                                  .read<OrderProvider>()
                                  .offersError ??
                                  'فشل إضافة العرض')),
                            ));
                          },
                          child: const Text('إضافة للسلة'),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
