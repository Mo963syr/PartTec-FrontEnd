import 'package:flutter/material.dart';
import '../../utils/app_settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../utils/session_store.dart';
import '../../models/part.dart';

import '../supplier/SellerPartDetailsPage.dart';

class AddedPartsPage extends StatefulWidget {
  const AddedPartsPage({super.key});

  @override
  State<AddedPartsPage> createState() => _AddedPartsPageState();
}

class _AddedPartsPageState extends State<AddedPartsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // إضافة تبويب "الكل" وتجهيز الفئات
  final List<String> _categories = [
    'الكل',
    'محرك',
    'فرامل',
    'هيكل',
    'كهرباء',
    'إطارات',
    'نظام التعليق',
  ];

  Map<String, List<dynamic>> categorizedParts = {};

  bool isLoading = true;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initCategoriesMap();
    _tabController = TabController(length: _categories.length, vsync: this);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    fetchParts();
  }

  void _initCategoriesMap() {
    categorizedParts = {for (var cat in _categories) cat: []};
  }

  Future<void> fetchParts() async {
    setState(() => isLoading = true);
    try {
      final uid = await SessionStore.userId();
      final role = await SessionStore.role();
      debugPrint('🔑 User ID: $uid | 🎭 Role: $role');

      if (uid == null || uid.isEmpty) {
        debugPrint('❌ لا يوجد مستخدم مسجل');
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${AppSettings.serverurl}/part/viewsellerParts/$uid'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> parts = data['parts'] ?? [];

        _initCategoriesMap();

        // إضافة جميع القطع إلى قسم "الكل"
        categorizedParts['الكل'] = List.from(parts);

        // توزيع القطع على بقية الأقسام
        for (var part in parts) {
          final category = (part['category'] ?? '').toString();
          if (categorizedParts.containsKey(category) && category != 'الكل') {
            categorizedParts[category]!.add(part);
          }
        }
      } else {
        debugPrint('فشل في تحميل القطع: ${response.body}');
      }
    } catch (e) {
      debugPrint('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'بحث بالاسم، الموديل، أو الرقم التسلسلي...',
                    border: InputBorder.none,
                  ),
                )
              : const Text('القطع المضافة'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            controller: _tabController,
            tabs: _categories.map((cat) => Tab(text: cat)).toList(),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchParts,
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((category) {
                    final parts = categorizedParts[category] ?? [];

                    // تصفية نتائج البحث حسب الاسم، الرقم التسلسلي، أو اسم/موديل السيارة
                    final query = _searchQuery.trim().toLowerCase();
                    final List<dynamic> displayed = query.isEmpty
                        ? parts
                        : parts.where((p) {
                            final name =
                                (p['name'] ?? '').toString().toLowerCase();
                            final model =
                                (p['model'] ?? '').toString().toLowerCase();
                            final serial =
                                (p['serialNumber'] ?? p['serial_number'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            return name.contains(query) ||
                                model.contains(query) ||
                                serial.contains(query);
                          }).toList();

                    if (displayed.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Text(
                              'لا توجد قطع مطابقة',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> part =
                            Map<String, dynamic>.from(displayed[index]);

                        final imageUrl = part['imageUrl']?.toString();
                        final name = part['name']?.toString() ?? 'بدون اسم';
                        final manufacturer =
                            part['manufacturer']?.toString() ?? 'غير محدد';
                        final model = part['model']?.toString() ?? '-';
                        final year = part['year']?.toString() ?? '-';
                        final status = part['status']?.toString() ?? '-';
                        final serialNumber = (part['serialNumber'] ??
                                part['serial_number'] ??
                                '-')
                            .toString();

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final refreshed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SellerPartDetailsPage(
                                    part: Part.fromJson(part),
                                  ),
                                ),
                              );

                              if (refreshed == true) {
                                fetchParts();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // صورة القطعة
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: (imageUrl != null &&
                                            imageUrl.isNotEmpty)
                                        ? Image.network(
                                            imageUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image,
                                                size: 40, color: Colors.grey),
                                          ),
                                  ),
                                  const SizedBox(width: 12),

                                  // تفاصيل القطعة
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'المصنّع: $manufacturer',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blueGrey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'الموديل: $model | السنة: $year',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              'الحالة: $status',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'S/N: $serialNumber',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }
}
