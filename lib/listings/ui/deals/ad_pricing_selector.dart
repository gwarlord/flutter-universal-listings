import 'package:flutter/material.dart';

class AdPricingSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onDaysChanged;
  final double pricePerDay;
  final double? seasonalMultiplier;

  const AdPricingSelector({
    Key? key,
    required this.selectedDays,
    required this.onDaysChanged,
    this.pricePerDay = 10.0,
    this.seasonalMultiplier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double multiplier = seasonalMultiplier ?? 1.0;
    final double total = selectedDays * pricePerDay * multiplier;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black54;
    return Card(
      color: cardColor,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Ad Duration', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: iconColor),
                  onPressed: selectedDays > 1 ? () => onDaysChanged(selectedDays - 1) : null,
                ),
                Text('$selectedDays days', style: TextStyle(color: textColor, fontSize: 16)),
                IconButton(
                  icon: Icon(Icons.add, color: iconColor),
                  onPressed: () => onDaysChanged(selectedDays + 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Price per day: \$${pricePerDay.toStringAsFixed(2)}', style: TextStyle(color: textColor)),
            if (multiplier > 1.0)
              Text('Seasonal rate: x${multiplier.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 8),
            Text('Total: \$${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}
