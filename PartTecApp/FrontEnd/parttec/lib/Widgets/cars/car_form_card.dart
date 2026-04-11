import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/car_data.dart';
import '../../controllers/vin_image_controller.dart';
import '../../providers/car_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/vin_provider.dart';

class CarFormCard extends StatefulWidget {
  const CarFormCard({super.key});

  @override
  State<CarFormCard> createState() => _CarFormCardState();
}

class _CarFormCardState extends State<CarFormCard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vinController = TextEditingController();
  final VinImageController _vinImageController = VinImageController();

  String? selectedBrandCode;
  String? selectedBrandName;
  String? selectedModel;
  String? selectedYear;
  String? serialNumber;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final carProvider = context.read<CarProvider>();

      if (carProvider.brands.isEmpty) {
        await carProvider.fetchBrands();
      }

      final savedVin = await _vinImageController.restoreVinLocally();
      if (!mounted) return;

      if (savedVin != null && savedVin.isNotEmpty) {
        setState(() {
          serialNumber = savedVin;
          _vinController.text = savedVin;
        });
      }

      final lostFile = await _vinImageController.recoverLostImage();
      if (!mounted || lostFile == null) return;

      await _handlePickedVinFile(lostFile);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _vinImageController.saveVinLocally(_vinController.text.trim());
    }
  }

  bool _isValidVin(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return true;
    return RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(v);
  }

  Future<void> _handlePickedVinFile(XFile file) async {
    final vinProvider = context.read<VinProvider>();

    final vin = await _vinImageController.extractVinFromFile(
      file: file,
      vinProvider: vinProvider,
    );

    if (!mounted) return;

    if (vin == null || vin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vinProvider.errorMessage ?? 'لم يتم العثور على رقم شاصي واضح',
          ),
        ),
      );
      return;
    }

    setState(() {
      serialNumber = vin;
      _vinController.text = vin;
    });

    await _vinImageController.saveVinLocally(vin);
    await _vinImageController.copyVin(vin);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم استخراج رقم الشاصي ونسخه إلى الحافظة'),
      ),
    );
  }

  Future<void> _pickVinImage(ImageSource source) async {
    try {
      final file = await _vinImageController.pickImage(source);
      if (file == null) return;
      await _handlePickedVinFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة: $e')),
      );
    }
  }

  Widget _buildVinActions(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickVinImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('تصوير رقم الشاصي'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickVinImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('اختيار صورة'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final carProvider = context.watch<CarProvider>();
    final homeProvider = context.read<HomeProvider>();
    final vinProvider = context.watch<VinProvider>();

    final selectedBrandItem = selectedBrandCode == null
        ? null
        : (carProvider.brands.any((e) => e['code'] == selectedBrandCode)
            ? carProvider.brands.firstWhere(
                (e) => e['code'] == selectedBrandCode,
              )
            : null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بيانات السيارة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _vinController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 17,
                decoration: InputDecoration(
                  labelText: 'رقم الشاصي (VIN)',
                  hintText: 'مثال: WAUZZZ4G4DN141331',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: const OutlineInputBorder(),
                  counterText: '',
                  suffixIcon: vinProvider.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_vinController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () async {
                                final text = _vinController.text.trim();
                                if (text.isEmpty) return;
                                await _vinImageController.copyVin(text);
                              },
                            )
                          : null),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final upper = newValue.text.toUpperCase();
                    if (upper.length > 17) return oldValue;
                    return TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }),
                ],
                validator: (value) {
                  final v = (value ?? '').trim().toUpperCase();
                  if (v.isEmpty) return null;
                  if (v.length != 17) return 'يجب أن يكون VIN من 17 خانة';
                  if (!_isValidVin(v)) return 'VIN غير صالح';
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    serialNumber = value.toUpperCase();
                  });
                  _vinImageController.saveVinLocally(value.trim().toUpperCase());
                },
              ),

              const SizedBox(height: 10),
              _buildVinActions(vinProvider.isLoading),
              const SizedBox(height: 18),

              if (carProvider.isLoadingBrands)
                const Center(child: CircularProgressIndicator())
              else
                DropdownSearch<Map<String, dynamic>>(
                  items: carProvider.brands,
                  itemAsString: (item) => item['name']?.toString() ?? '',
                  selectedItem: selectedBrandItem,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'الشركة المصنعة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  onChanged: (value) async {
                    final code = value?['code']?.toString();
                    final name = value?['name']?.toString();

                    setState(() {
                      selectedBrandCode = code;
                      selectedBrandName = name;
                      selectedModel = null;
                      selectedYear = null;
                    });

                    if (code == null || code.isEmpty) return;
                    await context.read<CarProvider>().fetchModels(code);
                  },
                ),

              const SizedBox(height: 16),

              if (selectedBrandCode != null)
                carProvider.isLoadingModels
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownSearch<String>(
                        items: carProvider.models,
                        selectedItem: selectedModel,
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'موديل السيارة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        onChanged: (value) {
                          setState(() => selectedModel = value);
                        },
                      ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'سنة الصنع',
                  border: OutlineInputBorder(),
                ),
                items: CarData.years
                    .map(
                      (y) => DropdownMenuItem<String>(
                        value: y,
                        child: Text(y),
                      ),
                    )
                    .toList(),
                value: selectedYear,
                onChanged: (v) => setState(() => selectedYear = v),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ السيارة'),
                  onPressed: () async {
                    if (selectedBrandName == null ||
                        selectedModel == null ||
                        selectedYear == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى تحديد الشركة والموديل والسنة'),
                        ),
                      );
                      return;
                    }

                    if (!_formKey.currentState!.validate()) return;

                    final result = await homeProvider.submitCarDirect(
                      manufacturer: selectedBrandName!,
                      model: selectedModel!,
                      year: selectedYear!,
                      serialNumber: serialNumber?.trim().isEmpty == true
                          ? null
                          : serialNumber?.trim(),
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result ?? '✅ تم حفظ السيارة بنجاح'),
                      ),
                    );

                    if (result == null) {
                      await homeProvider.fetchUserCars();
                      context.read<CarProvider>().setCars(homeProvider.userCars);
                      await _vinImageController.clearSavedVinLocally();

                      setState(() {
                        selectedBrandCode = null;
                        selectedBrandName = null;
                        selectedModel = null;
                        selectedYear = null;
                        serialNumber = null;
                        _vinController.clear();
                      });
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