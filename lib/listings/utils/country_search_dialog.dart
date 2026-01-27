import 'package:flutter/material.dart';
import 'caribbean_countries.dart';

Future<String?> showCountrySearchDialog(BuildContext context, String? selectedCode) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return _CountrySearchDialog(selectedCode: selectedCode);
    },
  );
}

class _CountrySearchDialog extends StatefulWidget {
  final String? selectedCode;

  const _CountrySearchDialog({this.selectedCode});

  @override
  State<_CountrySearchDialog> createState() => _CountrySearchDialogState();
}

class _CountrySearchDialogState extends State<_CountrySearchDialog> {
  late TextEditingController _searchController;
  late List<CaribbeanCountry> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = List.from(CaribbeanCountries.all);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.dialogBackgroundColor;
    final textColor = theme.textTheme.bodyMedium?.color;
    final iconColor = theme.iconTheme.color;
    return AlertDialog(
      backgroundColor: backgroundColor,
      title: Text('Select Country', style: TextStyle(color: textColor)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: TextStyle(color: textColor?.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: iconColor),
                isDense: true,
                filled: true,
                fillColor: isDark ? theme.cardColor : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _filtered = CaribbeanCountries.all
                      .where((c) => c.name.toLowerCase().contains(value.toLowerCase()))
                      .toList();
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No countries found', style: TextStyle(color: textColor)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final c = _filtered[i];
                          return ListTile(
                            title: Text(c.name, style: TextStyle(color: textColor)),
                            selected: c.code == widget.selectedCode,
                            selectedTileColor: isDark ? theme.colorScheme.primary.withOpacity(0.15) : Colors.grey[200],
                            onTap: () => Navigator.of(context).pop(c.code),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary)),
        ),
      ],
    );
  }
}
