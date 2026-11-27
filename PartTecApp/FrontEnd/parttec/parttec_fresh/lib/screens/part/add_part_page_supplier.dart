import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/add_part_provider.dart';
import '../../utils/app_settings.dart';
import '../../theme/app_theme.dart';
import '../qr/qr_scan_page.dart';
import 'package:parttec/utils/session_store.dart';

class _PickedPartImage {
  final Uint8List bytes;
  final String name;
  final File? file;

  const _PickedPartImage({
    required this.bytes,
    required this.name,
    this.file,
  });
}

class KiaPartAddPage extends StatefulWidget {
  const KiaPartAddPage({super.key});

  @override
  State<KiaPartAddPage> createState() => _KiaPartAddPageState();
}

class _KiaPartAddPageState extends State<KiaPartAddPage> {
  static const String _manualOption = 'أخرى (يدوي)';
  static const String _defaultWarehouse = 'مجمع القدم';

  final _formKey = GlobalKey<FormState>();

  final List<String> years = [
    '2020',
    '2021',
    '2022',
    '2023',
    '2024',
    _manualOption,
  ];
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
    _manualOption,
  ];
  final List<String> categories = [
    'محرك',
    'فرامل',
    'كهرباء',
    'هيكل',
    _manualOption,
  ];
  final List<String> statuses = ['جديد', 'مستعمل', _manualOption];
  final List<String> warehouses = [
    _defaultWarehouse,
    'مستودع القدم',
    _manualOption,
  ];

  List<String> brands = [_manualOption];
  List<String> models = [_manualOption];

  String? selectedBrand;
  String? selectedModel;
  String? selectedYear;
  String? selectedPart;
  String? selectedCategory;
  String? selectedStatus;
  String selectedWarehouse = _defaultWarehouse;

  // الوضع اليدوي الافتراضي للموديل وسنة الصنع واسم القطعة
  bool isCustomBrand = false;
  bool isCustomModel = true;
  bool isCustomYear = true;
  bool isCustomPart = true;
  bool isCustomCategory = false;
  bool isCustomStatus = false;
  bool isCustomWarehouse = false;

  final customBrandController = TextEditingController();
  final customModelController = TextEditingController();
  final customYearController = TextEditingController();
  final customPartController = TextEditingController();
  final customCategoryController = TextEditingController();
  final customStatusController = TextEditingController();
  final customWarehouseController = TextEditingController(
    text: _defaultWarehouse,
  );

  final priceController = TextEditingController();
  final serialNumberController = TextEditingController();
  final countController = TextEditingController(text: '1');

  final List<_PickedPartImage> _pickedImages = [];

  // سجلات سابقة للاقتراحات أثناء الكتابة
  final Map<String, List<String>> _historyByField = {
    'brand': [],
    'model': [],
    'year': [],
    'part': [],
    'category': [],
    'status': [],
    'warehouse': [_defaultWarehouse],
    'serial': [],
    'price': [],
    'count': ['1'],
  };

  String? _activeSuggestionField;

  bool isSubmitting = false;
  bool isBrandsLoading = false;
  bool isModelsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistorySuggestions();
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
    customCategoryController.dispose();
    customStatusController.dispose();
    customWarehouseController.dispose();
    super.dispose();
  }

  String get _finalBrand => isCustomBrand
      ? customBrandController.text.trim()
      : (selectedBrand ?? '');
  String get _finalModel => isCustomModel
      ? customModelController.text.trim()
      : (selectedModel ?? '');
  String get _finalYear =>
      isCustomYear ? customYearController.text.trim() : (selectedYear ?? '');
  String get _finalPart =>
      isCustomPart ? customPartController.text.trim() : (selectedPart ?? '');
  String get _finalCategory => isCustomCategory
      ? customCategoryController.text.trim()
      : (selectedCategory ?? '');
  String get _finalStatus => isCustomStatus
      ? customStatusController.text.trim()
      : (selectedStatus ?? '');
  String get _finalWarehouse {
    final val = isCustomWarehouse
        ? customWarehouseController.text.trim()
        : selectedWarehouse.trim();
    return val.isEmpty ? _defaultWarehouse : val;
  }

  Future<void> _loadHistorySuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = <String, List<String>>{};
      for (final key in _historyByField.keys) {
        final saved = prefs.getStringList('parttec_history_$key') ?? [];
        updated[key] = saved;
      }
      if (mounted) {
        setState(() {
          for (final entry in updated.entries) {
            _historyByField[entry.key] = {
              ...entry.value,
              ..._historyByField[entry.key]!,
            }.toList();
          }
        });
      }
    } catch (_) {
      // تجاهل أخطاء التخزين المحلي
    }
  }

  Future<void> _saveCurrentValuesToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pairs = <String, String>{
        'brand': _finalBrand,
        'model': _finalModel,
        'year': _finalYear,
        'part': _finalPart,
        'category': _finalCategory,
        'status': _finalStatus,
        'warehouse': _finalWarehouse,
        'serial': serialNumberController.text.trim(),
        'price': priceController.text.trim(),
        'count': countController.text.trim(),
      };

      for (final entry in pairs.entries) {
        final val = entry.value.trim();
        if (val.isEmpty) continue;
        final existing = List<String>.from(_historyByField[entry.key] ?? []);
        existing.removeWhere((item) => item.toLowerCase() == val.toLowerCase());
        existing.insert(0, val);
        final trimmed = existing.take(15).toList();
        _historyByField[entry.key] = trimmed;
        await prefs.setStringList('parttec_history_${entry.key}', trimmed);
      }
    } catch (_) {
      // تجاهل أخطاء الحفظ المحلي
    }
  }

  List<String> _filteredSuggestions(String fieldKey, String query) {
    final source = <String>{
      ...(_historyByField[fieldKey] ?? const []),
      if (fieldKey == 'brand') ...brands.where((e) => e != _manualOption),
      if (fieldKey == 'model') ...models.where((e) => e != _manualOption),
      if (fieldKey == 'year') ...years.where((e) => e != _manualOption),
      if (fieldKey == 'part') ...partsList.where((e) => e != _manualOption),
      if (fieldKey == 'category') ...categories.where((e) => e != _manualOption),
      if (fieldKey == 'status') ...statuses.where((e) => e != _manualOption),
      if (fieldKey == 'warehouse')
        ...warehouses.where((e) => e != _manualOption),
    };

    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? source.toList()
        : source.where((item) => item.toLowerCase().contains(q)).toList();

    return matches.take(6).toList();
  }

  Future<void> _fetchBrands() async {
    setState(() => isBrandsLoading = true);
    try {
      final uid = await SessionStore.userId();
      final url = Uri.parse(
        '${AppSettings.serverurl}/user/viewsellerprands/$uid',
      );
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final list = (data['prands'] as List<dynamic>? ?? [])
            .map((b) => (b as String).capitalize())
            .toSet()
            .toList();
        list.add(_manualOption);
        if (mounted) {
          setState(() => brands = list);
        }
      } else if (mounted) {
        setState(() => brands = [_manualOption]);
      }
    } catch (_) {
      if (mounted) {
        setState(() => brands = [_manualOption]);
      }
    } finally {
      if (mounted) {
        setState(() => isBrandsLoading = false);
      }
    }
  }

  Future<void> _fetchModels(String brand) async {
    if (brand.isEmpty || brand == _manualOption) {
      setState(() {
        selectedModel = null;
        models = [_manualOption];
      });
      return;
    }

    setState(() {
      isModelsLoading = true;
      selectedModel = null;
      models = [_manualOption];
    });

    final url = Uri.parse(
      '${AppSettings.serverurl}/api/models?brand=${Uri.encodeComponent(brand.toLowerCase())}',
    );
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final list = List<String>.from(data['models'] ?? []);
        list.add(_manualOption);
        if (mounted) {
          setState(() => models = list);
        }
      }
    } catch (_) {
      // الإبقاء على الإدخال اليدوي عند تعذر الجلب
    } finally {
      if (mounted) {
        setState(() => isModelsLoading = false);
      }
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 85);
    if (pickedList.isEmpty) return;

    final List<_PickedPartImage> newlyPicked = [];
    for (var i = 0; i < pickedList.length; i++) {
      final item = pickedList[i];
      final bytes = await item.readAsBytes();
      final name = item.name.isNotEmpty
          ? item.name
          : 'part_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      newlyPicked.add(
        _PickedPartImage(
          bytes: bytes,
          name: name,
          file: kIsWeb ? null : File(item.path),
        ),
      );
    }

    if (mounted) {
      setState(() => _pickedImages.addAll(newlyPicked));
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _pickedImages.length) return;
    setState(() => _pickedImages.removeAt(index));
  }

  List<http.MultipartFile> _buildMultipartImages() {
    return _pickedImages
        .map(
          (img) => http.MultipartFile.fromBytes(
            'images',
            img.bytes,
            filename: img.name,
          ),
        )
        .toList();
  }

  void _showFriendlyFeedback(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? Colors.green.shade700
            : Colors.red.shade700,
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mapFriendlyFailureMessage(String? rawError) {
    final text = (rawError ?? '').toLowerCase();
    if (text.contains('صيغة الصورة') || text.contains('filefilter')) {
      return 'تعذر رفع إحدى الصور؛ يرجى اختيار صور بصيغة JPG أو PNG أو WEBP.';
    }
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('timed out') ||
        text.contains('connection')) {
      return 'تعذر الاتصال بالخادم حالياً؛ تحقق من الشبكة وأعد المحاولة.';
    }
    return 'تعذر حفظ بيانات القطعة حالياً؛ يرجى مراجعة الحقول والمحاولة مرة أخرى.';
  }

  Future<void> _submit() async {
    if (isSubmitting) return;

    setState(() => _activeSuggestionField = null);

    final isValidForm = _formKey.currentState?.validate() ?? false;
    if (!isValidForm ||
        _finalBrand.isEmpty ||
        _finalModel.isEmpty ||
        _finalYear.isEmpty ||
        _finalPart.isEmpty ||
        _finalCategory.isEmpty ||
        _finalStatus.isEmpty ||
        _pickedImages.isEmpty) {
      _showFriendlyFeedback(
        'يرجى إكمال جميع الحقول المطلوبة واختيار صورة واحدة على الأقل.',
        isSuccess: false,
      );
      return;
    }

    setState(() => isSubmitting = true);

    final provider = context.read<AddPartProvider>();
    final multipartImages = _buildMultipartImages();
    final imageBytesList = _pickedImages.map((e) => e.bytes).toList();
    final imageFilesList = _pickedImages
        .map((e) => e.file)
        .whereType<File>()
        .toList();

    final ok = await provider.addPart(
      name: _finalPart,
      manufacturer: _finalBrand.toLowerCase(),
      model: _finalModel,
      year: _finalYear,
      category: _finalCategory,
      status: _finalStatus,
      price: priceController.text.trim(),
      image: imageFilesList.isNotEmpty ? imageFilesList.first : null,
      images: multipartImages,
      imageFiles: imageFilesList,
      imageBytesList: imageBytesList,
      serialNumber: serialNumberController.text.trim(),
      description: '',
      count: int.tryParse(countController.text.trim()) ?? 1,
      warehouse: _finalWarehouse,
    );

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (ok) {
      await _saveCurrentValuesToHistory();
      _showFriendlyFeedback(
        'تمت إضافة القطعة بنجاح إلى $_finalWarehouse.',
        isSuccess: true,
      );
    } else {
      _showFriendlyFeedback(
        _mapFriendlyFailureMessage(provider.errorMessage),
        isSuccess: false,
      );
    }
  }

  Widget _buildSuggestionsBar({
    required String fieldKey,
    required String currentQuery,
    required ValueChanged<String> onSuggestionTap,
  }) {
    if (_activeSuggestionField != fieldKey) return const SizedBox.shrink();

    final suggestions = _filteredSuggestions(fieldKey, currentQuery);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions.map((s) {
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 13)),
            avatar: const Icon(Icons.history, size: 16),
            onPressed: () {
              onSuggestionTap(s);
              setState(() => _activeSuggestionField = null);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDefaultManualWithQuickPick({
    required String fieldKey,
    required String label,
    required List<String> quickItems,
    required String? selectedQuickValue,
    required bool isManualMode,
    required TextEditingController manualController,
    required String manualHint,
    required ValueChanged<String?> onQuickSelected,
    required VoidCallback onEnableManual,
    bool isNumericOnly = false,
    bool isLoading = false,
  }) {
    final dropdownOptions = quickItems.where((e) => e != _manualOption).toList();
    final safeQuickValue =
        dropdownOptions.contains(selectedQuickValue) ? selectedQuickValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isLoading ? '$label (جاري التحميل...)' : label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onEnableManual,
              icon: Icon(
                isManualMode ? Icons.edit : Icons.arrow_drop_down_circle,
                size: 18,
              ),
              label: Text(isManualMode ? 'إدخال يدوي' : 'اختيار من القائمة'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!isManualMode)
          DropdownButtonFormField<String>(
            value: safeQuickValue,
            isExpanded: true,
            hint: Text('اختر $label من القائمة'),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: dropdownOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onQuickSelected,
            validator: (val) {
              if (manualController.text.trim().isEmpty &&
                  (val == null || val.isEmpty)) {
                return 'يرجى تحديد أو إدخال $label';
              }
              return null;
            },
          ),
        if (isManualMode) ...[
          DropdownButtonFormField<String>(
            value: safeQuickValue,
            isExpanded: true,
            hint: Text('تعبئة سريعة من القائمة (اختياري)'),
            decoration: InputDecoration(
              labelText: 'قائمة سريعة لـ $label',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: dropdownOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onQuickSelected,
          ),
          const SizedBox(height: AppSpaces.sm),
          TextFormField(
            controller: manualController,
            keyboardType:
                isNumericOnly ? TextInputType.number : TextInputType.text,
            inputFormatters:
                isNumericOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              labelText: manualHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onTap: () => setState(() => _activeSuggestionField = fieldKey),
            onChanged: (val) {
              setState(() {
                _activeSuggestionField = fieldKey;
                if (selectedQuickValue != null &&
                    val.trim() != selectedQuickValue) {
                  selectedQuickValue = null;
                }
              });
            },
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال $label';
              }
              return null;
            },
          ),
          _buildSuggestionsBar(
            fieldKey: fieldKey,
            currentQuery: manualController.text,
            onSuggestionTap: (suggestion) {
              setState(() {
                manualController.text = suggestion;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownWithManual({
    required String fieldKey,
    required String label,
    required List<String> items,
    required String? value,
    required bool isCustom,
    required TextEditingController customController,
    required String customHint,
    required ValueChanged<String?> onChanged,
    bool isNumericOnly = false,
    bool isLoading = false,
  }) {
    final safeValue = items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: isLoading ? '$label (جاري التحميل...)' : label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: (val) {
            setState(() => _activeSuggestionField = null);
            onChanged(val);
          },
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'يرجى اختيار $label';
            }
            if (val == _manualOption && customController.text.trim().isEmpty) {
              return 'يرجى إدخال قيمة $label يدوياً';
            }
            return null;
          },
        ),
        if (isCustom) ...[
          const SizedBox(height: AppSpaces.sm),
          TextFormField(
            controller: customController,
            keyboardType:
                isNumericOnly ? TextInputType.number : TextInputType.text,
            inputFormatters:
                isNumericOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              labelText: customHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onTap: () => setState(() => _activeSuggestionField = fieldKey),
            onChanged: (_) => setState(() => _activeSuggestionField = fieldKey),
            validator: (val) {
              if (isCustom && (val == null || val.trim().isEmpty)) {
                return customHint;
              }
              return null;
            },
          ),
          _buildSuggestionsBar(
            fieldKey: fieldKey,
            currentQuery: customController.text,
            onSuggestionTap: (suggestion) {
              setState(() => customController.text = suggestion);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildImagesPreview() {
    if (_pickedImages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpaces.sm),
        Text(
          'الصور المختارة (${_pickedImages.length}):',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpaces.xs),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pickedImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final img = _pickedImages[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      img.bytes,
                      width: 105,
                      height: 105,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: InkWell(
                      onTap: () => _removeImageAt(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
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
      ],
    );
  }

  Widget _buildAnimatedSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submit,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isSubmitting
              ? const Row(
                  key: ValueKey('submitting_state'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('جاري الإرسال...'),
                  ],
                )
              : const Row(
                  key: ValueKey('idle_state'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send),
                    SizedBox(width: 8),
                    Text('إرسال'),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة قطعة')),
      body: GestureDetector(
        onTap: () {
          if (_activeSuggestionField != null) {
            setState(() => _activeSuggestionField = null);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpaces.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDropdownWithManual(
                  fieldKey: 'brand',
                  label: 'البراند',
                  items: brands,
                  value: selectedBrand,
                  isCustom: isCustomBrand,
                  customController: customBrandController,
                  customHint: 'أدخل اسم البراند يدوياً',
                  isLoading: isBrandsLoading,
                  onChanged: (val) {
                    setState(() {
                      selectedBrand = val;
                      isCustomBrand = (val == _manualOption);
                      if (!isCustomBrand) {
                        customBrandController.clear();
                      }
                      selectedModel = null;
                      customModelController.clear();
                    });
                    if (val != null && val != _manualOption) {
                      _fetchModels(val);
                    } else {
                      setState(() => models = [_manualOption]);
                    }
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                // الموديل: يدوي افتراضياً مع إمكانية التحديد من القائمة
                _buildDefaultManualWithQuickPick(
                  fieldKey: 'model',
                  label: 'الموديل',
                  quickItems: models,
                  selectedQuickValue: selectedModel,
                  isManualMode: isCustomModel,
                  manualController: customModelController,
                  manualHint: 'اكتب اسم الموديل يدوياً',
                  isLoading: isModelsLoading,
                  onQuickSelected: (val) {
                    setState(() {
                      selectedModel = val;
                      if (val != null) {
                        customModelController.text = val;
                      }
                    });
                  },
                  onEnableManual: () {
                    setState(() => isCustomModel = !isCustomModel);
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                // سنة الصنع: يدوي افتراضياً مع إمكانية التحديد من القائمة
                _buildDefaultManualWithQuickPick(
                  fieldKey: 'year',
                  label: 'سنة الصنع',
                  quickItems: years,
                  selectedQuickValue: selectedYear,
                  isManualMode: isCustomYear,
                  manualController: customYearController,
                  manualHint: 'اكتب سنة الصنع يدوياً (أرقام فقط)',
                  isNumericOnly: true,
                  onQuickSelected: (val) {
                    setState(() {
                      selectedYear = val;
                      if (val != null) {
                        customYearController.text = val;
                      }
                    });
                  },
                  onEnableManual: () {
                    setState(() => isCustomYear = !isCustomYear);
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                // اسم القطعة: يدوي افتراضياً مع إمكانية التحديد من القائمة
                _buildDefaultManualWithQuickPick(
                  fieldKey: 'part',
                  label: 'اسم القطعة',
                  quickItems: partsList,
                  selectedQuickValue: selectedPart,
                  isManualMode: isCustomPart,
                  manualController: customPartController,
                  manualHint: 'اكتب اسم القطعة يدوياً',
                  onQuickSelected: (val) {
                    setState(() {
                      selectedPart = val;
                      if (val != null) {
                        customPartController.text = val;
                      }
                    });
                  },
                  onEnableManual: () {
                    setState(() => isCustomPart = !isCustomPart);
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                _buildDropdownWithManual(
                  fieldKey: 'category',
                  label: 'التصنيف',
                  items: categories,
                  value: selectedCategory,
                  isCustom: isCustomCategory,
                  customController: customCategoryController,
                  customHint: 'أدخل التصنيف يدوياً',
                  onChanged: (val) {
                    setState(() {
                      selectedCategory = val;
                      isCustomCategory = (val == _manualOption);
                      if (!isCustomCategory) {
                        customCategoryController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                _buildDropdownWithManual(
                  fieldKey: 'status',
                  label: 'الحالة',
                  items: statuses,
                  value: selectedStatus,
                  isCustom: isCustomStatus,
                  customController: customStatusController,
                  customHint: 'أدخل الحالة يدوياً',
                  onChanged: (val) {
                    setState(() {
                      selectedStatus = val;
                      isCustomStatus = (val == _manualOption);
                      if (!isCustomStatus) {
                        customStatusController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                _buildDropdownWithManual(
                  fieldKey: 'warehouse',
                  label: 'المستودع',
                  items: warehouses,
                  value: selectedWarehouse,
                  isCustom: isCustomWarehouse,
                  customController: customWarehouseController,
                  customHint: 'أدخل اسم المستودع يدوياً',
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      selectedWarehouse = val;
                      isCustomWarehouse = (val == _manualOption);
                      if (!isCustomWarehouse) {
                        customWarehouseController.text = val;
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpaces.md),

                TextFormField(
                  controller: serialNumberController,
                  decoration: InputDecoration(
                    labelText: 'الرقم التسلسلي (اختياري)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final code = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QRScanPage(),
                          ),
                        );
                        if (code != null) {
                          setState(() {
                            serialNumberController.text = code.toString();
                          });
                        }
                      },
                    ),
                  ),
                  onTap: () => setState(() => _activeSuggestionField = 'serial'),
                  onChanged: (_) =>
                      setState(() => _activeSuggestionField = 'serial'),
                ),
                _buildSuggestionsBar(
                  fieldKey: 'serial',
                  currentQuery: serialNumberController.text,
                  onSuggestionTap: (s) =>
                      setState(() => serialNumberController.text = s),
                ),
                const SizedBox(height: AppSpaces.md),

                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'السعر (بالدولار)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () => setState(() => _activeSuggestionField = 'price'),
                  onChanged: (_) =>
                      setState(() => _activeSuggestionField = 'price'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال السعر';
                    }
                    if (double.tryParse(val.trim()) == null) {
                      return 'أدخل رقماً صحيحاً للسعر';
                    }
                    return null;
                  },
                ),
                _buildSuggestionsBar(
                  fieldKey: 'price',
                  currentQuery: priceController.text,
                  onSuggestionTap: (s) =>
                      setState(() => priceController.text = s),
                ),
                const SizedBox(height: AppSpaces.md),

                TextFormField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'عدد القطع',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () => setState(() => _activeSuggestionField = 'count'),
                  onChanged: (_) =>
                      setState(() => _activeSuggestionField = 'count'),
                  validator: (val) {
                    final parsed = int.tryParse(val?.trim() ?? '');
                    if (parsed == null || parsed < 1) {
                      return 'يرجى إدخال عدد قطع صحيح (1 أو أكثر)';
                    }
                    return null;
                  },
                ),
                _buildSuggestionsBar(
                  fieldKey: 'count',
                  currentQuery: countController.text,
                  onSuggestionTap: (s) =>
                      setState(() => countController.text = s),
                ),
                const SizedBox(height: AppSpaces.md),

                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(
                    _pickedImages.isEmpty
                        ? 'اختيار صور القطعة *'
                        : 'إضافة صور أخرى (${_pickedImages.length})',
                  ),
                ),
                _buildImagesPreview(),
                const SizedBox(height: AppSpaces.lg),

                _buildAnimatedSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}