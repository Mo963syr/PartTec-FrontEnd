import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class OrderItemDetailsPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const OrderItemDetailsPage({Key? key, required this.item}) : super(key: key);

  double _numToDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? 'بدون اسم').toString();
    final img = (item['imageUrl'] ?? '').toString();
    final qty = (_numToDouble(item['quantity'])).toInt();
    final price = _numToDouble(item['price']);
    final total =
        item['total'] != null ? _numToDouble(item['total']) : (price * qty);
    final partId = (item['partId'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل القطعة'),
        // استخدم اللون الأساسي للتطبيق
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (img.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                img,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 220,
                    child: Center(
                        child: Icon(Icons.image_not_supported, size: 40))),
              ),
            )
          else
            const SizedBox(
              height: 220,
              child: Center(child: Icon(Icons.build, size: 48)),
            ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (partId.isNotEmpty) Text('Part ID: $partId'),
          const SizedBox(height: 8),
          if (price > 0) Text('السعر: ${price.toStringAsFixed(2)}'),
          Text('الكمية: $qty'),
          const Divider(height: 24),
          Row(
            children: [
              const Text('الإجمالي:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(total.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
