import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CarsSlider extends StatefulWidget {
  final List<dynamic> cars;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const CarsSlider({super.key, required this.cars, this.onEdit, this.onDelete});

  @override
  State<CarsSlider> createState() => _CarsSliderState();
}

class _CarsSliderState extends State<CarsSlider> {
  final PageController _page = PageController(viewportFraction: 0.86);
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.cars.isEmpty) {
      return Center(
          child: Text('لا توجد سيارات بعد — أضِف سيارتك من التبويب التالي.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700])));
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: widget.cars.length,
            onPageChanged: (i) => setState(() => _index = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) {
              final c = widget.cars[i];
              final title = '${c['manufacturer']} ${c['model']}';
              final sub = 'سنة ${c['year']} • ${c['fuel'] ?? 'غير محدد'}';
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(
                    right: 10,
                    left: i == 0 ? 2 : 0,
                    bottom: _index == i ? 0 : 10,
                    top: _index == i ? 0 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: Offset(0, 10))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                            color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.directions_car,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            Text(sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: -6,
                              children: [
                                if (c['vin'] != null &&
                                    (c['vin'] as String).isNotEmpty)
                                  _pill('VIN: ${c['vin']}'),
                                if (c['engine'] != null)
                                  _pill('محرك: ${c['engine']}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _miniBtn(
                              icon: Icons.edit,
                              tooltip: 'تعديل',
                              onTap: widget.onEdit),
                          const SizedBox(height: 8),
                          _miniBtn(
                              icon: Icons.delete,
                              tooltip: 'حذف',
                              onTap: widget.onDelete),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.cars.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 18 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _pill(String t) => Chip(
        label: Text(t,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );

  Widget _miniBtn(
          {required IconData icon, String? tooltip, VoidCallback? onTap}) =>
      Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      );
}
