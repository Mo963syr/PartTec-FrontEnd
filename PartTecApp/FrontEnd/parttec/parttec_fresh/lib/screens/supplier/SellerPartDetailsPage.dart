import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/part.dart';
import '../../utils/app_settings.dart';
import '../../theme/app_theme.dart';

class _EditableImageItem {
  final Uint8List bytes;
  final String filename;

  const _EditableImageItem({
    required this.bytes,
    required this.filename,
  });
}

class SellerPartDetailsPage extends StatefulWidget {
  final Part part;
  const SellerPartDetailsPage({super.key, required this.part});

  @override
  State<SellerPartDetailsPage> createState() => _SellerPartDetailsPageState();
}

class _SellerPartDetailsPageState extends State<SellerPartDetailsPage> {
  late Part _part;
  late List<String> _galleryUrls;
  final PageController _galleryController = PageController();
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _part = widget.part;
    _galleryUrls = _extractGalleryUrls(_part);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  String _resolveUrl(dynamic raw) {
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

  List<String> _extractGalleryUrls(Part part) {
    final List<String> result = [];

    try {
      final dynamic dynPart = part;
      final dynamic modelImages = dynPart.images;
      if (modelImages is List) {
        for (final item in modelImages) {
          final resolved = _resolveUrl(item);
          if (resolved.isNotEmpty && !result.contains(resolved)) {
            result.add(resolved);
          }
        }
      }
    } catch (_) {}

    if (result.isEmpty) {
      final fallback = _resolveUrl(part.imageUrl);
      if (fallback.isNotEmpty) {
        result.add(fallback);
      }
    }

    return result;
  }

  String _normalizeFilename(String rawName, int index) {
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    final cleaned = rawName.trim();
    final dotIdx = cleaned.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < cleaned.length - 1) {
      final ext = cleaned.substring(dotIdx + 1).toLowerCase();
      if (allowed.contains(ext)) {
        final base = cleaned
            .substring(0, dotIdx)
            .replaceAll(RegExp(r'[^\w-]'), '_');
        return '${base.isEmpty ? 'part_img_$index' : base}.$ext';
      }
    }
    return 'part_img_$index.jpg';
  }

  MediaType _resolveMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  void _openFullScreenGallery(int initialIndex) {
    if (_galleryUrls.isEmpty) return;
    final ctrl = PageController(initialPage: initialIndex);
    int idx = initialIndex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_part.name} (${idx + 1}/${_galleryUrls.length})',
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
                    controller: ctrl,
                    itemCount: _galleryUrls.length,
                    onPageChanged: (newIdx) => setDlg(() => idx = newIdx),
                    itemBuilder: (_, i) => InteractiveViewer(
                      child: Image.network(
                        _galleryUrls[i],
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

  Future<bool> _deletePart(BuildContext context, String id) async {
    try {
      final uri = Uri.parse('${AppSettings.serverurl}/part/delete/$id');
      final res = await http.delete(uri);
      if (res.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حذف القطعة ✅")),
          );
          Navigator.pop(context, true);
        }
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الحذف: ${res.body}")),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء الحذف: $e")),
        );
      }
      return false;
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final part = _part;

    final nameC = TextEditingController(text: part.name);
    final modelC = TextEditingController(text: part.model ?? '');
    final yearC = TextEditingController(text: part.year.toString());
    final statusC = TextEditingController(text: part.status ?? '');
    final priceC = TextEditingController(text: part.price.toString());
    final categoryC = TextEditingController(text: part.category ?? '');
    final countC = TextEditingController(text: part.count.toString());
    final descriptionC = TextEditingController(text: part.description ?? '');

    final List<_EditableImageItem> newPickedImages = [];
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

            Future<void> pickMultipleImages() async {
              final List<XFile> pickedList =
                  await picker.pickMultiImage(imageQuality: 85);
              if (pickedList.isEmpty) return;

              final List<_EditableImageItem> added = [];
              for (var i = 0; i < pickedList.length; i++) {
                final item = pickedList[i];
                final bytes = await item.readAsBytes();
                final safeName = _normalizeFilename(
                  item.name,
                  newPickedImages.length + i,
                );
                added.add(_EditableImageItem(bytes: bytes, filename: safeName));
              }

              setSt(() => newPickedImages.addAll(added));
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
                                    OutlinedButton.icon(
                                      onPressed:
                                          saving ? null : pickMultipleImages,
                                      icon: const Icon(Icons.add_photo_alternate),
                                      label: Text(
                                        newPickedImages.isEmpty
                                            ? 'اختيار صور جديدة للقطعة'
                                            : 'إضافة صور أخرى (${newPickedImages.length})',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (newPickedImages.isNotEmpty) ...[
                                      const Text(
                                        'الصور الجديدة المختارة:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 100,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: newPickedImages.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 8),
                                          itemBuilder: (_, idx) {
                                            final item = newPickedImages[idx];
                                            return Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    item.bytes,
                                                    width: 96,
                                                    height: 96,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 3,
                                                  left: 3,
                                                  child: InkWell(
                                                    onTap: saving
                                                        ? null
                                                        : () => setSt(() =>
                                                            newPickedImages
                                                                .removeAt(idx)),
                                                    child: Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.black87,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(3),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ] else if (_galleryUrls.isNotEmpty) ...[
                                      const Text(
                                        'الصور الحالية:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 96,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _galleryUrls.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 8),
                                          itemBuilder: (_, idx) => ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              _galleryUrls[idx],
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: 96,
                                                height: 96,
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                    Icons.broken_image),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    const SizedBox(height: 6),
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
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setSt(() => saving = true);

                                      final uri = Uri.parse(
                                        '${AppSettings.serverurl}/part/update/${part.id}',
                                      );

                                      final request =
                                          http.MultipartRequest('PUT', uri);

                                      request.fields['name'] = nameC.text.trim();
                                      request.fields['model'] =
                                          modelC.text.trim();
                                      request.fields['year'] = yearC.text.trim();
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

                                      for (final item in newPickedImages) {
                                        request.files.add(
                                          http.MultipartFile.fromBytes(
                                            'images',
                                            item.bytes,
                                            filename: item.filename,
                                            contentType:
                                                _resolveMediaType(item.filename),
                                          ),
                                        );
                                      }

                                      final streamedResponse =
                                          await request.send();
                                      final res = await http.Response.fromStream(
                                        streamedResponse,
                                      );

                                      setSt(() => saving = false);

                                      if (res.statusCode == 200) {
                                        try {
                                          final decoded = jsonDecode(res.body);
                                          final updatedPartJson =
                                              (decoded is Map &&
                                                      decoded['part'] is Map)
                                                  ? Map<String, dynamic>.from(
                                                      decoded['part'],
                                                    )
                                                  : null;
                                          if (updatedPartJson != null &&
                                              mounted) {
                                            setState(() {
                                              _part = Part.fromJson(
                                                updatedPartJson,
                                              );
                                              _galleryUrls =
                                                  _extractGalleryUrls(_part);
                                              _activeImageIndex = 0;
                                            });
                                          }
                                        } catch (_) {}

                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text("تم تعديل القطعة ✅"),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "فشل التعديل: ${res.body}",
                                              ),
                                            ),
                                          );
                                        }
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

  Widget _buildGalleryCard() {
    if (_galleryUrls.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: AppColors.chipBorder,
            child: const Center(
              child: Icon(Icons.image, size: 64, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: PageView.builder(
                  controller: _galleryController,
                  itemCount: _galleryUrls.length,
                  onPageChanged: (idx) =>
                      setState(() => _activeImageIndex = idx),
                  itemBuilder: (_, idx) => GestureDetector(
                    onTap: () => _openFullScreenGallery(idx),
                    child: Image.network(
                      _galleryUrls[idx],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.chipBorder,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeImageIndex + 1} / ${_galleryUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_galleryUrls.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                scrollDirection: Axis.horizontal,
                itemCount: _galleryUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final isSelected = idx == _activeImageIndex;
                  return GestureDetector(
                    onTap: () {
                      _galleryController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _activeImageIndex = idx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _galleryUrls[idx],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 20),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final part = _part;

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
            _buildGalleryCard(),
            const SizedBox(height: AppSpaces.md),
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
                      label: "الكمية المتوفرة",
                      value: part.count.toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpaces.md),
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
                      "الوصف",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
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
            const SizedBox(height: AppSpaces.lg),
            Text(
              "التقييمات",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _RatingsSection(partId: part.id),
            const SizedBox(height: AppSpaces.md),
            _PartStarRating(partId: part.id),
            const SizedBox(height: AppSpaces.md),
            Text(
              "تقييمات الزبائن",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
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
                        content: const Text(
                          "هل أنت متأكد أنك تريد حذف هذه القطعة؟",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("إلغاء"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("حذف"),
                          ),
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
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
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

class _RatingsSection extends StatelessWidget {
  final String partId;
  const _RatingsSection({required this.partId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.chipBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpaces.md),
        child: Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text(
              'ملخص التقييمات للقطعة',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartStarRating extends StatelessWidget {
  final String partId;
  const _PartStarRating({required this.partId});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.star, color: Colors.amber, size: 22),
        Icon(Icons.star, color: Colors.amber, size: 22),
        Icon(Icons.star, color: Colors.amber, size: 22),
        Icon(Icons.star, color: Colors.amber, size: 22),
        Icon(Icons.star_border, color: Colors.amber, size: 22),
        SizedBox(width: 8),
        Text('4.0 / 5', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ReviewsGate extends StatelessWidget {
  final String partId;
  const _ReviewsGate({required this.partId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.chipBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpaces.md),
        child: Text(
          'لا توجد تعليقات إضافية معروضة حالياً.',
          style: TextStyle(color: AppColors.textWeak),
        ),
      ),
    );
  }
}