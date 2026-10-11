import 'package:flutter/material.dart';
import 'package:parttec/screens/part/add_part_page_supplier.dart';
import 'package:parttec/theme/app_theme.dart';
import 'package:parttec/uploadfile/uploadpartsexelpage.dart';
import 'package:parttec/widgets/ui_kit.dart';

class PartsSectionPage extends StatelessWidget {
  const PartsSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: const Text(
                  'قسم القطع',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpaces.md),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpaces.lg,
                    crossAxisSpacing: AppSpaces.lg,
                    childAspectRatio: 1,
                    children: [
                      _buildCard(
                        context,
                        icon: Icons.add_box,
                        title: 'إضافة قطعة',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KiaPartAddPage(),
                            ),
                          );
                        },
                      ),
                      _buildCard(
                        context,
                        icon: Icons.upload_file,
                        title: 'رفع قطع (Excel)',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UploadPartsExcelPage(),
                            ),
                          );
                        },
                      ),
                    ],
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
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
