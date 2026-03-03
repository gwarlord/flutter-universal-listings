import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/utils/listing_filter_helpers.dart';

class EventHomeCard extends StatelessWidget {
  final EventModel event;
  final GeoPoint? userLocation;

  const EventHomeCard({
    super.key,
    required this.event,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);
    final distanceKm = _distanceKm();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Color(cfg.colorPrimary).withOpacity(isDark ? 0.18 : 0.10),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: event.posterImageUrl.trim().isEmpty
                  ? Container(
                      width: double.infinity,
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                      child: Icon(
                        Icons.event,
                        size: 40,
                        color: Color(cfg.colorPrimary),
                      ),
                    )
                  : Image.network(
                      event.posterImageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 30,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a').format(startDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(cfg.colorPrimary),
                      ),
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceKm() {
    if (userLocation == null) {
      return null;
    }

    return ListingFilterHelpers.calculateDistance(
      userLocation!.latitude,
      userLocation!.longitude,
      event.latitude,
      event.longitude,
    );
  }
}
