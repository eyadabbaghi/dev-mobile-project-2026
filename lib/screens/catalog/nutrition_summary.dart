import 'package:flutter/material.dart';

import '../../models/food.dart';
import '../../theme/fit_theme.dart';

class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.nutrition});
  final NutritionFacts nutrition;
  static String amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  @override
  Widget build(BuildContext context) {
    final items = [
      ('kcal', amount(nutrition.calories), FitTheme.lime),
      ('prot.', '${amount(nutrition.proteinGrams)} g', const Color(0xFFB9DB87)),
      (
        'gluc.',
        '${amount(nutrition.carbohydrateGrams)} g',
        const Color(0xFF96D6C9),
      ),
      ('lip.', '${amount(nutrition.fatGrams)} g', const Color(0xFFE2D5AB)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              decoration: BoxDecoration(
                color: FitTheme.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FitTheme.border),
              ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      items[i].$2,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$1,
                    style: const TextStyle(color: FitTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 3,
                    width: 24,
                    decoration: BoxDecoration(
                      color: items[i].$3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
