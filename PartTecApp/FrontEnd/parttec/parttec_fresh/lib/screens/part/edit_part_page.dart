import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/part.dart';
import '../../providers/parts_provider.dart';

class EditPartPage extends StatefulWidget {
  final Part part;
  const EditPartPage({super.key, required this.part});

  @override
  State<EditPartPage> createState() => _EditPartPageState();
}

class _EditPartPageState extends State<EditPartPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameC;
  late final TextEditingController modelC;
  late final TextEditingController yearC;
  late final TextEditingController statusC;
  late final TextEditingController priceC;
  late final TextEditingController categoryC;
  late final TextEditingController descriptionC;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    nameC = TextEditingController(text: p.name);
    modelC = TextEditingController(text: p.model);
    yearC = TextEditingController(text: p.year.toString());
    statusC = TextEditingController(text: p.status);
    priceC = TextEditingController(text: p.price.toString());
    categoryC = TextEditingController(text: p.category);
    descriptionC = TextEditingController(text: p.description ?? '');
  }

  @override
  void dispose() {
    nameC.dispose();
    modelC.dispose();
    yearC.dispose();
    statusC.dispose();
    priceC.dispose();
    categoryC.dispose();
    descriptionC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ok = await Provider.of<PartsProvider>(context, listen: false)
        .updatePart(widget.part.id, {
      'name': nameC.text.trim(),
      'model': modelC.text.trim(),
      'year': yearC.text.trim(),
      'status': statusC.text.trim(),
      'price': priceC.text.trim(),
      'category': categoryC.text.trim(),
      if (descriptionC.text.trim().isNotEmpty)
        'description': descriptionC.text.trim(),
    });

    setState(() => _saving = false);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل التعديل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تعديل القطعة')),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: nameC,
                      decoration:
                          const InputDecoration(labelText: 'اسم القطعة'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
                    ),
                    TextFormField(
                      controller: modelC,
                      decoration: const InputDecoration(labelText: 'الموديل'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل الموديل' : null,
                    ),
                    TextFormField(
                      controller: yearC,
                      decoration: const InputDecoration(labelText: 'السنة'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل السنة' : null,
                    ),
                    TextFormField(
                      controller: statusC,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل الحالة' : null,
                    ),
                    TextFormField(
                      controller: priceC,
                      decoration: const InputDecoration(labelText: 'السعر'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل السعر' : null,
                    ),
                    TextFormField(
                      controller: categoryC,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل التصنيف' : null,
                    ),
                    TextFormField(
                      controller: descriptionC,
                      decoration:
                          const InputDecoration(labelText: 'الوصف (اختياري)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
              if (_saving) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
