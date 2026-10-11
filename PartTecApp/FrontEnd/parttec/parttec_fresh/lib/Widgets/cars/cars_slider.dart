import 'package:flutter/material.dart';

class CarsSlider extends StatefulWidget {
  final List<dynamic> cars;
  final void Function(Map<String, dynamic> car)? onEdit;
  final void Function(Map<String, dynamic> car)? onDelete;

  const CarsSlider({
    super.key,
    required this.cars,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CarsSlider> createState() => CarsSliderState();
}

class CarsSliderState extends State<CarsSlider> {
  final PageController _page = PageController(viewportFraction: 0.82);
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: widget.cars.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final c = Map<String, dynamic>.from(widget.cars[i]);

              final title =
                  '${c['manufacturer'] ?? ''} ${c['model'] ?? ''}'.trim();
              final year = '${c['year'] ?? ''}';
              final vin =
                  (c['serialNumber'] ?? c['vin'] ?? '').toString().trim();

              final isActive = _index == i;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(
                  right: 8,
                  left: i == 0 ? 2 : 0,
                  bottom: isActive ? 0 : 10,
                  top: isActive ? 0 : 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2196F3), Color(0xFF3949AB)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.isEmpty ? 'سيارة' : title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  year,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _miniBtn(
                                icon: Icons.edit,
                                tooltip: 'تعديل',
                                onTap: () => widget.onEdit?.call(c),
                              ),
                              const SizedBox(height: 8),
                              _miniBtn(
                                icon: Icons.delete,
                                tooltip: 'حذف',
                                onTap: () => widget.onDelete?.call(c),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (vin.isNotEmpty) _pill('VIN: $vin'),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );

  Widget _miniBtn({
    required IconData icon,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}