import 'package:flutter/material.dart';
import 'delivery_orders_page.dart';
import '../auth/auth_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({Key? key}) : super(key: key);

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  String? _userId;
  String? _role;

  @override
  void initState() {
    super.initState();
    _printUserData();
  }

  Future<void> _printUserData() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString('userId');
    final role = sp.getString('role');
    setState(() {
      _userId = id;
      _role = role;
    });

    debugPrint('🔑 UserId: $id');
    debugPrint('👤 Role: $role');
  }

  Future<void> _logout(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    try {
      final sp = await SharedPreferences.getInstance();

      await sp.remove('token');
      await sp.remove('userId');
      await sp.remove('role');
      await sp.remove('name');
      await sp.remove('email');
      await sp.remove('phoneNumber');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تسجيل الخروج: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة موظف التوصيل'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('مرحبا بك'),
                subtitle: Text(
                  _userId != null && _role != null
                      ? 'ID: $_userId\nRole: $_role'
                      : 'موظف التوصيل',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد تسجيل الخروج'),
                      content: const Text('هل تريد تسجيل الخروج وإنهاء الجلسة؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('خروج'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _logout(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 3 / 2,
          children: [
            _buildCard(
              icon: Icons.local_shipping_outlined,
              title: 'طلبات التوصيل',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeliveryOrdersPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Icon(icon, size: 50, color: Colors.teal)),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
}
