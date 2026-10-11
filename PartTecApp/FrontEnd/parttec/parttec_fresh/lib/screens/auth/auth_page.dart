import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../employee/DeliveryDashboard.dart';
import '../employee/mechanic_dashboard.dart';
import '../home/home_page.dart';
import '../location/ChooseDestinationPage.dart';
import '../../providers/auth_provider.dart';
import '../supplier/supplier_dashboard.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _registerFormKey = GlobalKey<FormState>();
  bool _agreeTerms = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _logUser(String? id, String? role) {
    debugPrint('🔑 userId: $id');
    debugPrint('👤 role: $role');
  }

  void _navigateByRole(String role) {
    Widget target;
    switch (role) {
      case 'user':
        target = const HomePage();
        break;
      case 'seller':
        target = const SupplierDashboard();
        break;
      case 'coordinator':
        target = const CoordinatorDashboardPage();
        break;
      case 'delevery':
        target = const DeliveryDashboard();
        break;
      case 'mechanic':
        target = const MechanicDashboard();
        break;
      default:
        target = const MechanicDashboard();
        break;
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  InputDecoration _input(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.chipBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpaces.md,
      vertical: AppSpaces.sm,
    ),
  );

  String? _vEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'الرجاء إدخال البريد';
    final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
    return ok ? null : 'بريد غير صالح';
  }

  String? _vPassword(String? v) {
    if (v == null || v.isEmpty) return 'الرجاء إدخال كلمة المرور';
    if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  String? _vName(String? v) {
    if (v == null || v.trim().isEmpty) return 'الرجاء إدخال الاسم';
    if (v.trim().length < 3) return 'الاسم قصير جداً';
    return null;
  }

  String? _vPhoneSy(String? v) {
    if (v == null || v.trim().isEmpty) return 'الرجاء إدخال رقم الموبايل';
    final ok = RegExp(r'^(?:\+963|00963|0)?9\d{8}$').hasMatch(v.trim());
    return ok ? null : 'رقم موبايل سوري غير صالح';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpaces.md),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 2),
                          ),
                          child: const Icon(Icons.car_repair,
                              size: 38, color: Colors.white),
                        ),
                        const SizedBox(height: AppSpaces.md),
                        const Text('مرحباً بك في PartTec',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpaces.lg),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return Card(
                              color: Colors.white.withOpacity(0.98),
                              elevation: 6,
                              shadowColor: Colors.black12,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpaces.lg),
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: TabBar(
                                        controller: _tabController,
                                        splashFactory: NoSplash.splashFactory,
                                        dividerColor: Colors.transparent,
                                        indicator: BoxDecoration(
                                          color: const Color(0x1A2196F3),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        labelColor: AppColors.primary,
                                        unselectedLabelColor:
                                        AppColors.textWeak,
                                        labelStyle: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                        tabs: const [
                                          Tab(
                                              icon: Icon(Icons.login),
                                              text: 'تسجيل دخول'),
                                          Tab(
                                              icon: Icon(Icons.person_add_alt),
                                              text: 'إنشاء حساب'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpaces.lg),
                                    SizedBox(
                                      height: 500,
                                      child: TabBarView(
                                        controller: _tabController,
                                        physics: const BouncingScrollPhysics(),
                                        children: [
                                          SingleChildScrollView(
                                            child: Form(
                                              key: _loginFormKey,
                                              child: Column(
                                                children: [
                                                  TextFormField(
                                                    controller: _loginEmailCtrl,
                                                    keyboardType: TextInputType
                                                        .emailAddress,
                                                    decoration: _input(
                                                        'البريد الإلكتروني',
                                                        icon: Icons.email),
                                                    validator: _vEmail,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  TextFormField(
                                                    controller: _loginPassCtrl,
                                                    obscureText: true,
                                                    decoration: _input(
                                                        'كلمة المرور',
                                                        icon: Icons.lock),
                                                    validator: _vPassword,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.lg),
                                                  Row(
                                                    children: [
                                                      const Spacer(),
                                                      TextButton(
                                                        onPressed: () {},
                                                        child: const Text(
                                                            'نسيت كلمة المرور؟'),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.lg),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      onPressed:
                                                      auth.isLoggingIn
                                                          ? null
                                                          : () async {
                                                        if (_loginFormKey
                                                            .currentState!
                                                            .validate()) {
                                                          final res =
                                                          await auth
                                                              .login(
                                                            email: _loginEmailCtrl
                                                                .text
                                                                .trim(),
                                                            password:
                                                            _loginPassCtrl
                                                                .text,
                                                          );
                                                          if (res !=
                                                              null) {
                                                            final id = auth
                                                                .userId ??
                                                                res['user']?['_id']?.toString() ??
                                                                res['_id']?.toString();
                                                            final r = auth
                                                                .role ??
                                                                res['role']?.toString() ??
                                                                res['user']?['role']?.toString() ??
                                                                '';
                                                            _logUser(
                                                                id,
                                                                r);
                                                            if (r
                                                                .isNotEmpty) {
                                                              _navigateByRole(
                                                                  r);
                                                            } else {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(content: Text('لم يتم إرجاع الدور من الخادم')));
                                                            }
                                                          } else {
                                                            ScaffoldMessenger.of(
                                                                context)
                                                                .showSnackBar(
                                                                SnackBar(content: Text(auth.lastError ?? 'حدث خطأ أثناء تسجيل الدخول')));
                                                          }
                                                        }
                                                      },
                                                      icon: auth.isLoggingIn
                                                          ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth:
                                                            2,
                                                            color: Colors
                                                                .white),
                                                      )
                                                          : const Icon(Icons
                                                          .check_circle),
                                                      label: Text(auth
                                                          .isLoggingIn
                                                          ? '... جارٍ الدخول'
                                                          : 'تسجيل الدخول'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            child: Form(
                                              key: _registerFormKey,
                                              child: Column(
                                                children: [
                                                  TextFormField(
                                                    controller: _nameCtrl,
                                                    decoration: _input(
                                                        'الاسم الكامل',
                                                        icon: Icons.person),
                                                    validator: _vName,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  TextFormField(
                                                    controller: _emailCtrl,
                                                    keyboardType: TextInputType
                                                        .emailAddress,
                                                    decoration: _input(
                                                        'البريد الإلكتروني',
                                                        icon: Icons.email),
                                                    validator: _vEmail,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  TextFormField(
                                                    controller: _phoneCtrl,
                                                    keyboardType:
                                                    TextInputType.phone,
                                                    decoration: _input(
                                                        'رقم الموبايل',
                                                        icon: Icons.phone),
                                                    validator: _vPhoneSy,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  TextFormField(
                                                    controller: _passCtrl,
                                                    obscureText: true,
                                                    decoration: _input(
                                                        'كلمة المرور',
                                                        icon: Icons.lock),
                                                    validator: _vPassword,
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  TextFormField(
                                                    controller: _pass2Ctrl,
                                                    obscureText: true,
                                                    decoration: _input(
                                                        'تأكيد كلمة المرور',
                                                        icon: Icons.lock_reset),
                                                    validator: (v) {
                                                      final base =
                                                      _vPassword(v);
                                                      if (base != null)
                                                        return base;
                                                      if (v != _passCtrl.text) {
                                                        return 'كلمتا المرور غير متطابقتين';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.md),
                                                  Row(
                                                    children: [
                                                      Checkbox(
                                                        value: _agreeTerms,
                                                        onChanged: (v) =>
                                                            setState(() =>
                                                            _agreeTerms =
                                                                v ?? false),
                                                        activeColor:
                                                        AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          'أوافق على الشروط والأحكام وسياسة الخصوصية',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[700]),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                      height: AppSpaces.lg),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      onPressed: (!_agreeTerms ||
                                                          context
                                                              .read<
                                                              AuthProvider>()
                                                              .isRegistering)
                                                          ? null
                                                          : () async {
                                                        final auth =
                                                        context.read<
                                                            AuthProvider>();
                                                        if (_registerFormKey
                                                            .currentState!
                                                            .validate()) {
                                                          final res =
                                                          await auth
                                                              .register(
                                                            name: _nameCtrl
                                                                .text
                                                                .trim(),
                                                            email:
                                                            _emailCtrl
                                                                .text
                                                                .trim(),
                                                            password:
                                                            _passCtrl
                                                                .text,
                                                            phoneNumber:
                                                            _phoneCtrl
                                                                .text
                                                                .trim(),
                                                          );
                                                          if (res !=
                                                              null) {
                                                            final id = auth
                                                                .userId ??
                                                                res['user']?['_id']
                                                                    ?.toString();
                                                            final r = auth
                                                                .role ??
                                                                (res['user']?['role'] ??
                                                                    res['role'] ??
                                                                    'user')
                                                                    .toString();
                                                            _logUser(
                                                                id, r);
                                                            _navigateByRole(
                                                                r);
                                                          } else {
                                                            ScaffoldMessenger.of(
                                                                context)
                                                                .showSnackBar(SnackBar(
                                                                content:
                                                                Text(auth.lastError ?? 'حدث خطأ أثناء إنشاء الحساب')));
                                                          }
                                                        }
                                                      },
                                                      icon: context
                                                          .watch<
                                                          AuthProvider>()
                                                          .isRegistering
                                                          ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth:
                                                            2,
                                                            color: Colors
                                                                .white),
                                                      )
                                                          : const Icon(Icons
                                                          .person_add_alt),
                                                      label: Text(
                                                        context
                                                            .watch<
                                                            AuthProvider>()
                                                            .isRegistering
                                                            ? '... جارٍ الإنشاء'
                                                            : 'إنشاء حساب',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpaces.lg),
                        Text('© PartTec - جميع الحقوق محفوظة',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppSpaces.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorDashboardPage extends StatelessWidget {
  const DoctorDashboardPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Doctor Dashboard')));
}

class CoordinatorDashboardPage extends StatelessWidget {
  const CoordinatorDashboardPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Coordinator Dashboard')));
}

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Employee Dashboard')));
}
