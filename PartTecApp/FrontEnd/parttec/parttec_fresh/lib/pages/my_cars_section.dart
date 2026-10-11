import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/car_provider.dart';
import '../providers/home_provider.dart';
import '../Widgets/cars/card_header.dart';
import '../Widgets/cars/cars_slider.dart';
import '../Widgets/cars/car_form_card.dart';

class MyCarsSection extends StatefulWidget {
  const MyCarsSection({super.key});

  @override
  State<MyCarsSection> createState() => _MyCarsSectionState();
}

class _MyCarsSectionState extends State<MyCarsSection> {
  String? _extractCarId(Map<String, dynamic> car) {
    return car['id']?.toString() ??
        car['_id']?.toString() ??
        car['carId']?.toString() ??
        car['vehicleId']?.toString();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final homeProvider = context.read<HomeProvider>();
      final carProvider = context.read<CarProvider>();

      if (homeProvider.userCars.isEmpty) {
        await homeProvider.fetchUserCars();
      }

      carProvider.setCars(homeProvider.userCars);
    });
  }

  Future<void> _deleteCar(Map<String, dynamic> car) async {
    final carProvider = context.read<CarProvider>();
    final homeProvider = context.read<HomeProvider>();

    final carId = _extractCarId(car);

    if (carId == null || carId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرف السيارة غير موجود')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف السيارة'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذه السيارة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await carProvider.deleteCar(carId);

    if (!mounted) return;

    if (success) {
      await homeProvider.fetchUserCars();
      carProvider.setCars(homeProvider.userCars);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف السيارة بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل حذف السيارة')),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> car) async {
    // اترك كود التعديل كما هو مؤقتًا
    // وبعدها نفصله لاحقًا إلى widget/dialog مستقل
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final cars = provider.userCars;

    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardHeader(title: 'سياراتي'),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.black54,
                    indicator: BoxDecoration(
                      color: Color(0x1A2196F3),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    tabs: [
                      Tab(icon: Icon(Icons.directions_car)),
                      Tab(icon: Icon(Icons.add_circle_outline)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 470,
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    cars.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد سيارات بعد — أضِف سيارتك من التبويب التالي.',
                              style: TextStyle(color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : CarsSlider(
                            cars: cars,
                            onEdit: _showEditDialog,
                            onDelete: _deleteCar,
                          ),
                    const SingleChildScrollView(
                      child: CarFormCard(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}