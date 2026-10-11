import 'package:flutter/material.dart';

class StarSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(filled ? Icons.star : Icons.star_border,
              size: 28, color: Colors.amber),
          onPressed: () => onChanged(i + 1),
        );
      }),
    );
  }
}
