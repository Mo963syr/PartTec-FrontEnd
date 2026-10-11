import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';

class LocationPickerPage extends StatefulWidget {
  final String userId;

  const LocationPickerPage({required this.userId, Key? key}) : super(key: key);

  @override
  _LocationPickerPageState createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng? selectedLocation;

  final mapController = MapController();
  final initialCenter = LatLng(33.5138, 36.2765);

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع'),
        // استخدم اللون الأساسي للتطبيق
        backgroundColor: AppColors.primary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: initialCenter,
              zoom: 13.0,
              onTap: (tapPosition, latlng) {
                setState(() {
                  selectedLocation = latlng;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              if (selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80,
                      height: 80,
                      point: selectedLocation!,
                      child: Icon(
                        Icons.location_on,
                        // استخدم اللون الأساسي بدلاً من الأحمر
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: () {
                  // عند تأكيد الموقع، نعيد الإحداثيات للصفحة السابقة بدلاً من إرسال الطلب مباشرةً
                  Navigator.of(context).pop(selectedLocation);
                },
                // استخدم لون الزر من الثيم
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('تأكيد الموقع'),
              ),
            ),
        ],
      ),
    );
  }
}
