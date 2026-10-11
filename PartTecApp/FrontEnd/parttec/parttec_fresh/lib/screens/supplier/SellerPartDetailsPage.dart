import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parttec/screens/part/part_reviews_section.dart';
import 'package:provider/provider.dart';

import '../../models/part.dart';
import '../../providers/parts_provider.dart';
import '../../utils/app_settings.dart';
import '../../utils/session_store.dart';
import '../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data'; // من أجل Uint8List
import 'package:flutter/foundation.dart'; // من أجل kIsWeb (اختياري)
import 'package:http_parser/http_parser.dart'; // للتحكم بنوع الملف (اختياري)

class SellerPartDetailsPage extends StatefulWidget {
  final Part part;
  const SellerPartDetailsPage({super.key, required this.part});

  @override
  State<SellerPartDetailsPage> createState() => _SellerPartDetailsPageState();
}

class _SellerPartDetailsPageState extends State<SellerPartDetailsPage> {
  Future<bool> _deletePart(BuildContext context, String id) async {
    try {
      final uri = Uri.parse('${AppSettings.serverurl}/part/delete/$id');
      final res = await http.delete(uri);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حذف القطعة ✅")),
        );
        Navigator.pop(context, true);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الحذف: ${res.body}")),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء الحذف: $e")),
      );
      return false;
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final part = widget.part;

    final nameC = TextEditingController(text: part.name);
    final modelC = TextEditingController(text: part.model ?? '');
    final yearC = TextEditingController(text: part.year.toString());
    final statusC = TextEditingController(text: part.status ?? '');
    final priceC = TextEditingController(text: part.price.toString());
    final categoryC = TextEditingController(text: part.category ?? '');
    final countC = TextEditingController(text: part.count.toString());
    final descriptionC = TextEditingController(text: part.description ?? '');

    // متغيرا حفظ بيانات الصورة للبايتات واسم الملف (متوافق مع الويب والموبايل)
    Uint8List? selectedImageBytes;
    String? selectedFileName;
    final ImagePicker picker = ImagePicker();

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            final dialogWidth = screenWidth > 700 ? 600.0 : screenWidth * 0.95;

            // دالة اختيار الصورة
            Future<void> pickImage() async {
              final XFile? image =
                  await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                final bytes = await image.readAsBytes();
                setSt(() {
                  selectedImageBytes = bytes;
                  selectedFileName = image.name;
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'تعديل القطعة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving ? null : () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Form(
                          key: formKey,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 520;

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // معاينة الصورة النقرية
                                    Center(
                                      child: GestureDetector(
                                        onTap: saving ? null : pickImage,
                                        child: Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                width: double.infinity,
                                                height: 180,
                                                color: Colors.grey.shade200,
                                                child: selectedImageBytes !=
                                                        null
                                                    ? Image.memory(
                                                        selectedImageBytes!,
                                                        fit: BoxFit.contain,
                                                      )
                                                    : (part.imageUrl != null &&
                                                            part.imageUrl
                                                                .isNotEmpty)
                                                        ? Image.network(
                                                            part.imageUrl,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (_,
                                                                    __, ___) =>
                                                                const Icon(
                                                                    Icons.image,
                                                                    size: 48),
                                                          )
                                                        : const Icon(
                                                            Icons.add_a_photo,
                                                            size: 48),
                                              ),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.all(8),
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (isWide)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: nameC,
                                              decoration: const InputDecoration(
                                                labelText: 'الاسم',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (v) =>
                                                  (v == null || v.isEmpty)
                                                      ? 'أدخل الاسم'
                                                      : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: modelC,
                                              decoration: const InputDecoration(
                                                labelText: 'الموديل',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      TextFormField(
                                        controller: nameC,
                                        decoration: const InputDecoration(
                                          labelText: 'الاسم',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'أدخل الاسم'
                                                : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: modelC,
                                        decoration: const InputDecoration(
                                          labelText: 'الموديل',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    if (isWide)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: yearC,
                                              decoration: const InputDecoration(
                                                labelText: 'السنة',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: statusC,
                                              decoration: const InputDecoration(
                                                labelText: 'الحالة',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      TextFormField(
                                        controller: yearC,
                                        decoration: const InputDecoration(
                                          labelText: 'السنة',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: statusC,
                                        decoration: const InputDecoration(
                                          labelText: 'الحالة',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    if (isWide)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: priceC,
                                              decoration: const InputDecoration(
                                                labelText: 'السعر',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: countC,
                                              decoration: const InputDecoration(
                                                labelText: 'الكمية المتوفرة',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      TextFormField(
                                        controller: priceC,
                                        decoration: const InputDecoration(
                                          labelText: 'السعر',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: countC,
                                        decoration: const InputDecoration(
                                          labelText: 'الكمية المتوفرة',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: categoryC,
                                      decoration: const InputDecoration(
                                        labelText: 'التصنيف',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: descriptionC,
                                      decoration: const InputDecoration(
                                        labelText: 'الوصف (اختياري)',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  saving ? null : () => Navigator.pop(ctx),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: Text(saving ? "جارٍ الحفظ..." : "حفظ"),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate())
                                        return;

                                      setSt(() => saving = true);

                                      final uri = Uri.parse(
                                        '${AppSettings.serverurl}/part/update/${part.id}',
                                      );

                                      final request =
                                          http.MultipartRequest('PUT', uri);

                                      request.fields['name'] =
                                          nameC.text.trim();
                                      request.fields['model'] =
                                          modelC.text.trim();
                                      request.fields['year'] =
                                          yearC.text.trim();
                                      request.fields['status'] =
                                          statusC.text.trim();
                                      request.fields['count'] =
                                          countC.text.trim();
                                      request.fields['price'] =
                                          priceC.text.trim();
                                      request.fields['category'] =
                                          categoryC.text.trim();
                                      request.fields['description'] =
                                          descriptionC.text.trim();

                                      // إرفاق الصورة كبايتات
                                      if (selectedImageBytes != null) {
                                        request.files.add(
                                          http.MultipartFile.fromBytes(
                                            'image',
                                            selectedImageBytes!,
                                            filename:
                                                selectedFileName ?? 'image.jpg',
                                          ),
                                        );
                                      }

                                      final streamedResponse =
                                          await request.send();
                                      final res =
                                          await http.Response.fromStream(
                                              streamedResponse);

                                      setSt(() => saving = false);

                                      if (res.statusCode == 200) {
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text("تم تعديل القطعة ✅")),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "فشل التعديل: ${res.body}")),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    final image = part.imageUrl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(part.name),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpaces.md),
          children: [
            // صورة المنتج داخل Card بحواف دائرية
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: image.isNotEmpty
                    ? Image.network(image, fit: BoxFit.contain)
                    : Container(
                        color: AppColors.chipBorder,
                        child: const Center(
                          child:
                              Icon(Icons.image, size: 64, color: Colors.white),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpaces.md),

            // الاسم والسعر
            Card(
              elevation: 0,
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.chipBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpaces.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "السعر: \$${part.price}",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpaces.md),

            // معلومات أساسية
            Card(
              elevation: 0,
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.chipBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpaces.md),
                child: Column(
                  children: [
                    _InfoRow(label: "الموديل", value: part.model ?? ''),
                    _InfoRow(label: "الماركة", value: part.manufacturer ?? ''),
                    _InfoRow(label: "السنة", value: part.year.toString()),
                    _InfoRow(label: "الفئة", value: part.category ?? ''),
                    _InfoRow(label: "الحالة", value: part.status ?? ''),
                    _InfoRow(
                        label: "الكمية المتوفرة", value: part.count.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpaces.md),

            // الوصف
            Card(
              elevation: 0,
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.chipBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpaces.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("الوصف",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                    const SizedBox(height: 6),
                    Text(
                      part.description ?? "لا يوجد وصف",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textWeak),
                    ),
                  ],
                ),
              ),
            ),

            // ⭐ التقييمات
            const SizedBox(height: AppSpaces.lg),
            Text("التقييمات",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 10),
            _RatingsSection(partId: part.id),
            const SizedBox(height: AppSpaces.md),
            _PartStarRating(partId: part.id),
            const SizedBox(height: AppSpaces.md),
            Text("تقييمات الزبائن",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            _ReviewsGate(partId: part.id),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("تعديل"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _showEditDialog(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("حذف"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("تأكيد الحذف"),
                        content:
                            const Text("هل أنت متأكد أنك تريد حذف هذه القطعة؟"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("إلغاء")),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("حذف")),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _deletePart(context, part.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف معلومة موحّد
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpaces.xs),
      child: Row(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.start,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textWeak),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⭐ قسم تحميل وعرض متوسط التقييمات
class _RatingsSection extends StatefulWidget {
  final String partId;
  const _RatingsSection({Key? key, required this.partId}) : super(key: key);

  @override
  State<_RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends State<_RatingsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PartRatingProvider>().fetchRating(widget.partId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartRatingProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (prov.ratingsCount == 0) {
          return const Text("لا توجد تقييمات بعد",
              style: TextStyle(fontWeight: FontWeight.w600));
        }
        return Row(
          children: [
            Row(
              children: List.generate(5, (i) {
                final filled = i < prov.averageRating.round();
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 20,
                  color: Colors.amber, // نُبقي لون النجمة ذهبيًا
                );
              }),
            ),
            const SizedBox(width: 6),
            Text(
              prov.averageRating.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 6),
            Text("(${prov.ratingsCount} تقييم)",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textWeak)),
          ],
        );
      },
    );
  }
}

class _ReviewsGate extends StatefulWidget {
  final String partId;
  const _ReviewsGate({Key? key, required this.partId}) : super(key: key);

  @override
  State<_ReviewsGate> createState() => _ReviewsGateState();
}

class _ReviewsGateState extends State<_ReviewsGate>
    with AutomaticKeepAliveClientMixin {
  late final Future<String?> _uidFuture;

  @override
  void initState() {
    super.initState();
    _uidFuture = SessionStore.userId();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<String?>(
      future: _uidFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final uid = snapshot.data;
        if (uid == null || uid.isEmpty) {
          return const Text("⚠️ الرجاء تسجيل الدخول لعرض/إضافة التقييمات.");
        }
        return PartReviewsSection(partId: widget.partId);
      },
    );
  }
}

class _PartStarRating extends StatefulWidget {
  final String partId;
  const _PartStarRating({Key? key, required this.partId}) : super(key: key);

  @override
  State<_PartStarRating> createState() => _PartStarRatingState();
}

class _PartStarRatingState extends State<_PartStarRating> {
  int _rating = 0;
  bool _submitting = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    SessionStore.userId().then((id) {
      if (mounted) setState(() => _uid = id);
    });
  }

  Future<void> _submit() async {
    if (_uid == null || _uid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول لإرسال التقييم')),
      );
      return;
    }
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر تقييمًا من 1 إلى 5')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final url =
          Uri.parse('${AppSettings.serverurl}/part/ratePart/${widget.partId}');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _uid, 'rating': _rating}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تقييمك بنجاح')),
        );
      } else {
        final msg = _extractError(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'فشل إرسال التقييم')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالخادم')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _extractError(String body) {
    try {
      final obj = jsonDecode(body);
      if (obj is Map && obj['message'] is String) return obj['message'];
      if (obj is Map && obj['error'] is String) return obj['error'];
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}
