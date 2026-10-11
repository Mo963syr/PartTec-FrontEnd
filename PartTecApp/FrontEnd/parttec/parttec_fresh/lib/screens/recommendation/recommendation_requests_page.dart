import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RecommendationRequestsPage extends StatelessWidget {
  const RecommendationRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التوصية'),
        // استخدام اللون الأساسي من الثيم بدلاً من الأزرق الصريح
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Text(
          'هنا سيتم عرض طلبات التوصية الواردة من الزبائن.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
