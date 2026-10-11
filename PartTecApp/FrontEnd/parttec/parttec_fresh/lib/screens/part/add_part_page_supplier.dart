import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../providers/add_part_provider.dart';
import '../../utils/app_settings.dart';
import '../../theme/app_theme.dart';
import '../qr/qr_scan_page.dart';
import 'package:parttec/utils/session_store.dart';

class KiaPartAddPage extends StatefulWidget {
  const KiaPartAddPage({super.key});

  @override
  State<KiaPartAddPage> createState() => _KiaPartAddPageState();
}

class _KiaPartAddPageState extends State<KiaPartAddPage> {
  final List<String> years = ['2020', '2021', '2022', '2023', '2024', 'أخرى (يدوي)'];
  final List<String> partsList = [
    'فلتر هواء',
    'كمبيوتر محرك',
    'ردياتير',
    'بواجي',
    'ضو',
    'ستوب',
    'طارة',
    'مخمدات',
    'غطا باكاج',
    'أخرى (يدوي)'
  ];
  final List<String> categories = ['محرك', 'فرامل', 'كهرباء', 'هيكل'];
  final List<String> statuses = ['جديد', 'مستعمل'];

  List<String> brands = [];
  List<String> models = [];

  String? selectedBrand;
  String? selectedModel;
  String? selectedYear;
  String? selectedPart;
  String? selectedCategory;
  String? selectedStatus;

  // التحكم بالإدخال اليدوي
  bool isCustomBrand = false;
  bool isCustomModel = false;
  bool isCustomYear = false;
  bool isCustomPart = false;

  final customBrandController = TextEditingController();
  final customModelController = TextEditingController();
  final customYearController = TextEditingController();
  final customPartController = TextEditingController();

  File? _pickedImageFile;
  Uint8List? _pickedImageBytes;

  final priceController = TextEditingController();
  final serialNumberController = TextEditingController();
  final countController = TextEditingController(text: "1");

  bool isLoading = false;
  bool isModelsLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBrands();
  }

  @override
  void dispose() {
    priceController.dispose();
    serialNumberController.dispose();
    countController.dispose();
    customBrandController.dispose();
    customModelController.dispose();
    customYearController.dispose();
    customPartController.dispose();
    super.dispose();
  }

  String get _finalBrand => isCustomBrand ? customBrandController.text.trim() : (selectedBrand ?? '');
  String get _finalModel => isCustomModel ? customModelController.text.trim() : (selectedModel ?? '');
  String get _finalYear => isCustomYear ? customYearController.text.trim() : (selectedYear ?? '');
  String get _finalPart => isCustomPart ? customPartController.text.trim() : (selectedPart ?? '');

  Future<void> _fetchBrands() async {
    final uid = await SessionStore.userId();
    final url = Uri.parse(
      '${AppSettings.serverurl}/user/viewsellerprands/$uid',
    );
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() {
          brands = (data['prands'] as List<dynamic>)
              .map((b) => (b as String).capitalize())
              .toList();
          brands.add('أخرى (يدوي)');
        });
      }
    } catch (_) {
      setState(() {
        brands = ['أخرى (يدوي)'];
      });
    }
  }

  Future<void> _fetchModels(String brand) async {
    if (isCustomBrand) {
      setState(() {
        models = ['أخرى (يدوي)'];
      });
      return;
    }
    setState(() => isModelsLoading = true);
    final url = Uri.parse(
      '${AppSettings.serverurl}/api/models?brand=${Uri.encodeComponent(brand.toLowerCase())}',
    );
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        models = List<String>.from(data['models']);
        models.add('أخرى (يدوي)');
      } else {
        models = ['أخرى (يدوي)'];
      }
    } catch (_) {
      models = ['أخرى (يدوي)'];
    }
    setState(() => isModelsLoading = false);
  }

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final f = await p.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final bytes = await f.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageFile = kIsWeb ? null : File(f.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_finalBrand.isEmpty ||
        _finalModel.isEmpty ||
        _finalYear.isEmpty ||
        _finalPart.isEmpty ||
        selectedCategory == null ||
        selectedStatus == null ||
        priceController.text.isEmpty ||
        countController.text.isEmpty ||
        _pickedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى تعبئة جميع الحقول واختيار صورة')),
      );
      return;
    }
    setState(() => isLoading = true);

    final ok = await context.read<AddPartProvider>().addPart(
      name: _finalPart,
      manufacturer: _finalBrand.toLowerCase(),
      model: _finalModel,
      year: _finalYear,
      category: selectedCategory!,
      status: selectedStatus!,
      price: priceController.text,
      image: _pickedImageFile,
      serialNumber: serialNumberController.text,
      description: "",
      count: int.tryParse(countController.text) ?? 1,
      warehouse: "مستودع القدم", // 👉 إضافة حقل المستودع لقيمته المطلوبة
    );

    setState(() => isLoading = false);

    final msg = ok
        ? '✅ تمت إضافة القطعة بنجاح'
        : (context.read<AddPartProvider>().errorMessage ?? 'فشل في الإضافة');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (ok) Navigator.pop(context);
  }

  int get _currentStep {
    if (selectedBrand == null || (isCustomBrand && _finalBrand.isEmpty)) return 0;
    if (selectedModel == null || (isCustomModel && _finalModel.isEmpty)) return 1;
    if (selectedYear == null || (isCustomYear && _finalYear.isEmpty)) return 2;
    if (selectedPart == null || (isCustomPart && _finalPart.isEmpty)) return 3;
    if (selectedCategory == null) return 4;
    if (selectedStatus == null) return 5;
    return 6;
  }

  Widget _buildCurrentStep(int step) {
    switch (step) {
      case 0:
        return _cardStepWithCustom(
          title: 'اختر البراند أو أدخله يدويًا:',
          options: brands,
          selected: selectedBrand,
          isCustom: isCustomBrand,
          customController: customBrandController,
          hintText: 'اكتب اسم البراند...',
          onSelect: (b) {
            setState(() {
              selectedBrand = b;
              if (b == 'أخرى (يدوي)') {
                isCustomBrand = true;
                selectedModel = null;
                isCustomModel = false;
                models = ['أخرى (يدوي)'];
              } else {
                isCustomBrand = false;
                customBrandController.clear();
                selectedModel = null;
                isCustomModel = false;
                _fetchModels(b);
              }
            });
          },
        );
      case 1:
        return _cardStepWithCustom(
          title: 'اختر الموديل أو أدخله يدويًا:',
          options: models,
          selected: selectedModel,
          isCustom: isCustomModel,
          customController: customModelController,
          hintText: 'اكتب اسم الموديل...',
          loading: isModelsLoading,
          onSelect: (m) {
            setState(() {
              selectedModel = m;
              isCustomModel = (m == 'أخرى (يدوي)');
              if (!isCustomModel) customModelController.clear();
            });
          },
        );
      case 2:
        return _cardStepWithCustom(
          title: 'اختر سنة الصنع أو أدخلها يدويًا:',
          options: years,
          selected: selectedYear,
          isCustom: isCustomYear,
          customController: customYearController,
          hintText: 'اكتب السنة (أرقام فقط)...',
          isNumericOnly: true,
          onSelect: (y) {
            setState(() {
              selectedYear = y;
              isCustomYear = (y == 'أخرى (يدوي)');
              if (!isCustomYear) customYearController.clear();
            });
          },
        );
      case 3:
        return _cardStepWithCustom(
          title: 'اختر اسم القطعة أو أدخله يدويًا:',
          options: partsList,
          selected: selectedPart,
          isCustom: isCustomPart,
          customController: customPartController,
          hintText: 'اكتب اسم القطعة...',
          onSelect: (p) {
            setState(() {
              selectedPart = p;
              isCustomPart = (p == 'أخرى (يدوي)');
              if (!isCustomPart) customPartController.clear();
            });
          },
        );
      case 4:
        return _cardStep('اختر التصنيف:', categories, selectedCategory,
            (c) => setState(() => selectedCategory = c));
      case 5:
        return _cardStep('اختر الحالة:', statuses, selectedStatus,
            (s) => setState(() => selectedStatus = s));
      default:
        return _buildFinalForm();
    }
  }

  Widget _cardStepWithCustom({
    required String title,
    required List<String> options,
    required String? selected,
    required bool isCustom,
    required TextEditingController customController,
    required String hintText,
    required void Function(String) onSelect,
    bool isNumericOnly = false,
    bool loading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardStep(title, options, selected, onSelect, loading: loading),
        if (isCustom) ...[
          const SizedBox(height: AppSpaces.md),
          TextField(
            controller: customController,
            autofocus: true,
            keyboardType: isNumericOnly ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumericOnly
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            decoration: InputDecoration(
              labelText: hintText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_circle, color: AppColors.primary),
                onPressed: () {
                  if (customController.text.trim().isNotEmpty) {
                    setState(() {});
                  }
                },
              ),
            ),
            onSubmitted: (_) {
              if (customController.text.trim().isNotEmpty) {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: AppSpaces.sm),
          ElevatedButton(
            onPressed: () {
              if (customController.text.trim().isNotEmpty) {
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء كتابة النص أولاً')),
                );
              }
            },
            child: const Text('متابعة'),
          ),
        ]
      ],
    );
  }

  Widget _cardStep<T>(
    String title,
    List<T> options,
    T? selected,
    void Function(T) onSelect, {
    bool loading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        const SizedBox(height: AppSpaces.sm),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((opt) {
              final txt = opt.toString();
              final isSel = opt == selected;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSel ? AppColors.primary : AppColors.chipBorder,
                      width: isSel ? 2 : 1),
                  boxShadow: [
                    if (isSel)
                      BoxShadow(
                        blurRadius: 8,
                        color: AppColors.primary.withOpacity(0.25),
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: InkWell(
                  onTap: () => onSelect(opt),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                    child: Text(
                      txt,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppColors.primary : AppColors.text,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFinalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: serialNumberController,
          decoration: InputDecoration(
            labelText: 'الرقم التسلسلي (اختياري)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                final code = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScanPage()),
                );
                if (code != null) {
                  setState(() {
                    serialNumberController.text = code;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpaces.md),
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'السعر (بالدولار)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: AppSpaces.md),
        TextField(
          controller: countController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'عدد القطع',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: AppSpaces.md),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image),
          label: const Text('اختيار صورة'),
        ),
        if (_pickedImageBytes != null) ...[
          const SizedBox(height: AppSpaces.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _pickedImageBytes!,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ],
        const SizedBox(height: AppSpaces.lg),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('إرسال'),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة قطعة')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(anim),
                child: child,
              ),
              child: SingleChildScrollView(
                key: ValueKey<int>(_currentStep),
                padding: const EdgeInsets.all(AppSpaces.md),
                child: _buildCurrentStep(_currentStep),
              ),
            ),
    );
  }
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}