import 'package:flutter/material.dart';

class FeaturedHotspotCard extends StatelessWidget {
  final String hotspotName;
  final String subtitle;
  final VoidCallback onTap;

  const FeaturedHotspotCard({
    super.key,
    required this.hotspotName,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.25)),
      ),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(
          child: Icon(Icons.location_on_outlined, size: 18),
        ),
        title: Text(
          hotspotName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
