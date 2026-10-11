import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_settings.dart';
import '../../utils/session_store.dart';

class SellerReviewsPage extends StatefulWidget {
  const SellerReviewsPage({super.key});

  @override
  State<SellerReviewsPage> createState() => _SellerReviewsPageState();
}

class _SellerReviewsPageState extends State<SellerReviewsPage> {
  bool _loading = false;
  String? _error;
  String? _sellerId;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSellerIdAndReviews();
  }

  Future<void> _loadSellerIdAndReviews() async {
    setState(() => _loading = true);

    try {

      final id = await SessionStore.userId();
      if (id == null) {
        setState(() {
          _error = "⚠️ لم يتم العثور على معرف البائع";
          _loading = false;
        });
        return;
      }

      _sellerId = id;


      final res = await http.get(
        Uri.parse('${AppSettings.serverurl}/reviews/seller/$id'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _items = (data['reviews'] as List?) ?? [];
      } else {
        _error = "فشل تحميل التقييمات (${res.statusCode})";
      }
    } catch (e) {
      _error = "حدث خطأ أثناء تحميل البيانات: $e";
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييمات البائع'),
        // استخدم اللون الأساسي للتطبيق
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Center(child: Text('لا توجد تقييمات بعد'))
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final r = _items[i];
          final rating = (r['rating'] ?? 0).toInt();
          final part = r['part'] ?? {};
          final user = r['user'] ?? {};

          return Card(
            child: ListTile(
              leading: part['imageUrl'] != null
                  ? CircleAvatar(
                backgroundImage:
                NetworkImage(part['imageUrl']),
              )
                  : const CircleAvatar(child: Icon(Icons.image)),
              title: Text(part['name'] ?? 'قطعة'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      5,
                          (k) => Icon(
                        k < rating
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  if ((r['comment'] ?? '').toString().isNotEmpty)
                    Text(r['comment']),
                  Text(
                    'بواسطة: ${user['name'] ?? 'مستخدم'}',
                    style: const TextStyle(
                      fontSize: 12,
                      // استخدم لون النص الضعيف من الثيم بدلاً من الرمادي الصريح
                      color: AppColors.textWeak,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
