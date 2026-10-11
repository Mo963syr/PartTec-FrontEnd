import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/parts_provider.dart';
import '../../models/part.dart';

class ManagePartsPage extends StatefulWidget {
  const ManagePartsPage({super.key});

  @override
  State<ManagePartsPage> createState() => _ManagePartsPageState();
}

class _ManagePartsPageState extends State<ManagePartsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => Provider.of<PartsProvider>(context, listen: false).fetchParts());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PartsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة القطع'),
        // استخدم اللون الأساسي المخصص للتطبيق بدلاً من الأزرق الصريح
        backgroundColor: AppColors.primary,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.parts.length,
              itemBuilder: (context, index) {
                final Part part = provider.parts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(part.name),
                    subtitle: Text("${part.manufacturer} - ${part.model}"),
                    trailing: IconButton(
                      // استعمل لون الخطأ من الثيم بدلاً من الأحمر الصريح
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('تأكيد الحذف'),
                            content: const Text('هل تريد حذف هذه القطعة؟'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('نعم'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await provider.deletePart(part.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
