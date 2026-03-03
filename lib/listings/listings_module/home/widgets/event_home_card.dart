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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EventHomeCard({
    super.key,
    required this.event,
    this.userLocation,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);
    final distanceKm = _distanceKm();
    final primaryColor = Color(cfg.colorPrimary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: primaryColor.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Stack(
                      children: [
                        // Image
                        Positioned.fill(
                          child: event.posterImageUrl.trim().isEmpty
                              ? Container(
                                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.event_note_rounded,
                                    size: 50,
                                    color: primaryColor.withOpacity(0.5),
                                  ),
                                )
                              : Image.network(
                                  event.posterImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                  ),
                                ),
                        ),
                        // Gradient Overlay for readability
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.4),
                                ],
                                stops: const [0.0, 0.3, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Date Badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('MMM').format(startDate).toUpperCase(),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd').format(startDate),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Event Label
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'EVENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Distance Badge
                        if (distanceKm != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on, size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                size: 14,
                                color: isDark ? Colors.white70 : Colors.black54
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.venueName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('h:mm a').format(startDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
