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

  String _resolveFullImageUrl(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    final base = AppSettings.serverurl.endsWith('/')
        ? AppSettings.serverurl.substring(0, AppSettings.serverurl.length - 1)
        : AppSettings.serverurl;
    final path = str.startsWith('/') ? str : '/$str';
    return '$base$path';
  }

  List<String> _extractPartImages(Map<String, dynamic> part) {
    final List<String> urls = [];

    final rawImages = part['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        final resolved = _resolveFullImageUrl(item);
        if (resolved.isNotEmpty && !urls.contains(resolved)) {
          urls.add(resolved);
        }
      }
    }

    if (urls.isEmpty) {
      final fallback = _resolveFullImageUrl(
        part['imageUrl'] ?? part['image_url'] ?? part['image'],
      );
      if (fallback.isNotEmpty) {
        urls.add(fallback);
      }
    }

    return urls;
  }

  void _openImageGalleryDialog(
    BuildContext context,
    List<String> images,
    int initialIndex,
    String partName,
  ) {
    final pageController = PageController(initialPage: initialIndex);
    int currentIdx = initialIndex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$partName (${currentIdx + 1}/${images.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: images.length,
                    onPageChanged: (idx) {
                      setDialogState(() => currentIdx = idx);
                    },
                    itemBuilder: (_, idx) => InteractiveViewer(
                      child: Image.network(
                        images[idx],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartImagesWidget(
    BuildContext context,
    List<String> images,
    String partName,
  ) {
    if (images.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, size: 38, color: Colors.grey),
      );
    }

    if (images.length == 1) {
      return GestureDetector(
        onTap: () => _openImageGalleryDialog(context, images, 0, partName),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            images.first,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 84,
              height: 84,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 176,
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, imgIndex) {
          return GestureDetector(
            onTap: () =>
                _openImageGalleryDialog(context, images, imgIndex, partName),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    images[imgIndex],
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84,
                      height: 84,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${imgIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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

                        final images = _extractPartImages(part);
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
                                  // صور القطعة من مصفوفة images
                                  _buildPartImagesWidget(
                                      context, images, name),
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