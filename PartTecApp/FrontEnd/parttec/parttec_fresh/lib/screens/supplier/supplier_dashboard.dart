import 'package:flutter/material.dart';
import 'package:parttec/screens/part/PartsSectionPage.dart';
import 'package:parttec/theme/app_theme.dart';
import 'package:parttec/widgets/ui_kit.dart';

import 'package:parttec/screens/order/my_order_page.dart';
import '../auth/auth_page.dart';
import '../cart/cart_page.dart';
import '../order/MyOrdersDashboard.dart';
import '../order/recommendation_orders_page.dart';
import '../order/GroupedOrdersPage.dart';
import '../part/added_parts_page.dart';
import 'DeliveredOrdersPage.dart';
import 'sellers.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/user_provider.dart';
import '../../utils/session_store.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  LatLng? _pinnedLocation;

  Future<void> _loadPinnedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('user_lat');
    final lng = prefs.getDouble('user_lng');
    if (lat != null && lng != null) {
      setState(() => _pinnedLocation = LatLng(lat, lng));
    }
  }

  Future<void> _savePinnedLocationLocal(LatLng p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_lat', p.latitude);
    await prefs.setDouble('user_lng', p.longitude);
    setState(() => _pinnedLocation = p);
  }

  Future<LatLng?> _pickLocationOnMap() async {
    final initial = _pinnedLocation ?? const LatLng(33.5138, 36.2765);
    return await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.6,
        builder: (ctx, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: const Material(
              color: Colors.white, child: _LocationPickerSheet()),
        ),
      ),
    );
  }

  Future<void> _pinUserLocationToProfile() async {
    final picked = await _pickLocationOnMap();
    if (picked == null) return;

    await _savePinnedLocationLocal(picked);

    if (!mounted) return;
    final userProv = Provider.of<UserProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري حفظ موقعك في الحساب...')),
    );

    final ok = await userProv.updateUserLocation(
      lat: picked.latitude,
      lng: picked.longitude,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ موقعك في الحساب بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userProv.error ?? 'تعذّر حفظ الموقع')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPinnedLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text('مرحباً بك'),
                subtitle: Text('مورد PartTec'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.blue),
                title: const Text('تثبيت موقعي في الحساب'),
                subtitle: Text(
                  _pinnedLocation == null
                      ? 'غير محدّد'
                      : 'Lat: ${_pinnedLocation!.latitude.toStringAsFixed(6)}, '
                          'Lng: ${_pinnedLocation!.longitude.toStringAsFixed(6)}',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pinUserLocationToProfile();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await SessionStore.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: const Text(
                  'لوحة المورد',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpaces.md),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double maxWidth = constraints.maxWidth;
                      double cardWidth = (maxWidth / 2) - (AppSpaces.lg * 1.5);
                      double cardHeight = cardWidth;

                      return Wrap(
                        spacing: AppSpaces.lg,
                        runSpacing: AppSpaces.lg,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildCard(
                            context,
                            icon: Icons.widgets,
                            title: 'قسم القطع',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PartsSectionPage()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.edit_note,
                            title: 'طلباتي',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => MyOrdersDashboard()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.shopping_cart,
                            title: 'الطلبات المقدمة من الزبون',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => GroupedOrdersPage()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.view_list,
                            title: 'عرض القطع المضافة',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AddedPartsPage()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.recommend,
                            title: 'طلبات التوصية',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => RecommendationOrdersPage(
                                        roleOverride: 'user')),
                              );
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.storefront,
                            title: 'التجار',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const TradersDashboard()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.history,
                            title: 'السجل',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => DeliveredOrdersPage()));
                            },
                          ),
                          _buildCard(
                            context,
                            icon: Icons.shopping_basket,
                            title: 'سلة المشتريات',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CartPage(),
                                ),
                              );
                            },
                          ),
                        ].map((card) {
                          return SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: card,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppSpaces.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: AppSpaces.sm),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ودجت اختيار الموقع (نفس اللي بالـ HomePage)
class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();
  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final MapController _map = MapController();
  LatLng _center = const LatLng(33.5138, 36.2765);
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = _center;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Text(
            'اضغط على الخريطة لتثبيت الدبوس، ثم اضغط حفظ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onTap: (tapPos, latlng) => setState(() => _picked = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.parttec',
              ),
              if (_picked != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _picked!,
                    width: 42,
                    height: 42,
                    child: const Icon(Icons.location_pin,
                        size: 42, color: Colors.red),
                  ),
                ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _picked == null
                      ? 'لم يتم اختيار موقع'
                      : 'Lat: ${_picked!.latitude.toStringAsFixed(6)} • Lng: ${_picked!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop<LatLng>(null),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _picked == null
                    ? null
                    : () => Navigator.of(context).pop<LatLng>(_picked),
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
