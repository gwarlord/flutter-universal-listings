import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../model/rental_booking.dart';
import '../../model/rental_unit.dart';
import '../../model/rental_catalog_item.dart';
import '../../services/rental_service.dart';
import '../../services/rental_catalog_service.dart';

class RentalBookingDetailScreen extends StatefulWidget {
  final RentalBooking booking;

  const RentalBookingDetailScreen({
    Key? key,
    required this.booking,
  }) : super(key: key);

  @override
  State<RentalBookingDetailScreen> createState() => _RentalBookingDetailScreenState();
}

class _RentalBookingDetailScreenState extends State<RentalBookingDetailScreen> {
  final RentalService _rentalService = RentalService();
  final RentalCatalogService _catalogService = RentalCatalogService();

  RentalBooking get booking => widget.booking;

  Future<Map<String, dynamic>> _fetchItemData() async {
    debugPrint('🔍 DEBUG: _fetchItemData START for booking ${booking.id}');
    debugPrint('🔍 DEBUG: rentalUnitId: ${booking.rentalUnitId}, listingId: ${booking.listingId}');

    if (booking.rentalUnitId.isNotEmpty && booking.rentalUnitId != 'multiple') {
      // 1. Try raw rental_catalog first
      debugPrint('🔍 DEBUG: Attempting fetch from rental_catalog...');
      final rentalCatalogDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(booking.listingId)
          .collection('rental_catalog')
          .doc(booking.rentalUnitId)
          .get();
      if (rentalCatalogDoc.exists) {
        final rentalCatalogData = rentalCatalogDoc.data();
        debugPrint('🔍 DEBUG: Found in rental_catalog: ${rentalCatalogData?.keys}');
        final rentalName = (rentalCatalogData?['name'] as String?)?.trim() ?? '';
        final rentalPhotos = _extractPhotos(rentalCatalogData);
        debugPrint('🔍 DEBUG: rental_catalog name: $rentalName, photos: ${rentalPhotos.length}');
        if (rentalName.isNotEmpty || rentalPhotos.isNotEmpty) {
          return {
            'name': rentalName.isNotEmpty ? rentalName : 'Rental Item',
            'photos': rentalPhotos,
          };
        }
      }

      // 2. Try legacy rental_units next
      debugPrint('🔍 DEBUG: Attempting fetch from rental_units...');
      final rentalUnitDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(booking.listingId)
          .collection('rental_units')
          .doc(booking.rentalUnitId)
          .get();
      if (rentalUnitDoc.exists) {
        final rentalUnitData = rentalUnitDoc.data();
        debugPrint('🔍 DEBUG: Found in rental_units: ${rentalUnitData?.keys}');
        final unitName = (rentalUnitData?['unitName'] as String?)?.trim() ?? '';
        final unitPhotos = _extractPhotos(rentalUnitData);
        debugPrint('🔍 DEBUG: rental_units name: $unitName, photos: ${unitPhotos.length}');
        if (unitName.isNotEmpty || unitPhotos.isNotEmpty) {
          return {
            'name': unitName.isNotEmpty ? unitName : 'Rental Item',
            'photos': unitPhotos,
          };
        }
      }

      // 3. Service fallbacks
      debugPrint('🔍 DEBUG: Attempting fetch via RentalService...');
      final unit = await _rentalService.getRentalUnit(booking.listingId, booking.rentalUnitId);
      if (unit != null) {
        debugPrint('🔍 DEBUG: Found via RentalService: ${unit.unitName}, photos: ${unit.photoUrls.length}');
        return {
          'name': unit.unitName,
          'photos': unit.photoUrls,
        };
      }

      debugPrint('🔍 DEBUG: Attempting fetch via RentalCatalogService...');
      final catalogItem = await _catalogService.getRentalItem(booking.listingId, booking.rentalUnitId);
      if (catalogItem != null) {
        debugPrint('🔍 DEBUG: Found via RentalCatalogService: ${catalogItem.name}, photos: ${catalogItem.photos.length}');
        return {
          'name': catalogItem.name,
          'photos': catalogItem.photos,
        };
      }
    }

    // 4. Fall back to booking snapshot data (if present)
    debugPrint('🔍 DEBUG: Attempting fetch from rental_bookings snapshot...');
    final bookingDoc = await FirebaseFirestore.instance
        .collection('rental_bookings')
        .doc(booking.id)
        .get();
    final bookingData = bookingDoc.data();
    debugPrint('🔍 DEBUG: Booking snapshot data keys: ${bookingData?.keys}');

    final bookingPhotos = _extractPhotos(bookingData);
    if (bookingPhotos.isNotEmpty) {
      final bookingName =
          (bookingData?['unitName'] as String?)?.trim() ??
          (bookingData?['rentalItemName'] as String?)?.trim() ??
          (bookingData?['itemName'] as String?)?.trim() ??
          '';
      debugPrint('🔍 DEBUG: Found in booking snapshot: $bookingName, photos: ${bookingPhotos.length}');
      return {
        'name': bookingName.isNotEmpty ? bookingName : 'Rental Item',
        'photos': bookingPhotos,
      };
    }

    final cartItems = bookingData?['cartItems'];
    if (cartItems is List && cartItems.isNotEmpty) {
      debugPrint('🔍 DEBUG: Found ${cartItems.length} cartItems in booking snapshot');
      final first = cartItems.first;
      if (first is Map) {
        final firstMap = Map<String, dynamic>.from(first);
        final unitName = (firstMap['unitName'] as String?)?.trim() ?? '';
        final cartPhotos = _extractPhotos(firstMap);
        debugPrint('🔍 DEBUG: Found in cartItem[0]: $unitName, photos: ${cartPhotos.length}');
        if (unitName.isNotEmpty || cartPhotos.isNotEmpty) {
          return {
            'name': unitName,
            'photos': cartPhotos,
          };
        }
      }
    }

    // 5. Final fallback: listing-level title/photo
    debugPrint('🔍 DEBUG: Final fallback: listing document...');
    final listingDoc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(booking.listingId)
        .get();
    final listingData = listingDoc.data();
    debugPrint('🔍 DEBUG: Listing data keys: ${listingData?.keys}');
    final listingName = (listingData?['title'] as String?)?.trim() ?? '';
    final listingPhotos = _extractPhotos(listingData);
    debugPrint('🔍 DEBUG: Listing fallback: $listingName, photos: ${listingPhotos.length}');

    if (listingName.isNotEmpty || listingPhotos.isNotEmpty) {
      return {
        'name': listingName.isNotEmpty ? listingName : 'Rental Item',
        'photos': listingPhotos,
      };
    }

    debugPrint('🔍 DEBUG: _fetchItemData FAILED - returning default');
    return {'name': 'Rental Item', 'photos': const <String>[]};
  }

  List<String> _extractPhotos(Map<String, dynamic>? data) {
    if (data == null) return const <String>[];

    final photoUrls = data['photoUrls'];
    if (photoUrls is List) {
      final parsed = photoUrls
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final photos = data['photos'];
    if (photos is List) {
      final parsed = photos
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final photoUrl = (data['photoUrl'] as String?)?.trim() ??
        (data['photoURL'] as String?)?.trim() ??
        (data['listingPhoto'] as String?)?.trim() ??
        (data['thumbnailUrl'] as String?)?.trim() ??
        (data['imageUrl'] as String?)?.trim() ??
        (data['photo'] as String?)?.trim() ??
        (data['image'] as String?)?.trim() ??
        '';

    if (photoUrl.isNotEmpty) {
      return [photoUrl];
    }

    return const <String>[];
  }

  Future<_CustomerPreview> _fetchCustomerPreview() async {
    if (booking.customerId.isEmpty) {
      return const _CustomerPreview(name: 'Customer');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(booking.customerId)
        .get();
    if (!userDoc.exists) {
      return const _CustomerPreview(name: 'Customer');
    }

    final data = userDoc.data();
    final firstName = (data?['firstName'] as String?)?.trim() ?? '';
    final lastName = (data?['lastName'] as String?)?.trim() ?? '';
    final displayName = (data?['displayName'] as String?)?.trim() ?? '';
    final fullName = (data?['name'] as String?)?.trim() ?? '';
    final email = (data?['email'] as String?)?.trim() ?? '';
    final phone = (data?['phoneNumber'] as String?)?.trim() ??
        (data?['phone'] as String?)?.trim() ?? '';
    final profilePictureURL = (data?['profilePictureURL'] as String?)?.trim() ?? '';

    final combinedName = '$firstName $lastName'.trim();
    final resolvedName = combinedName.isNotEmpty
        ? combinedName
        : (displayName.isNotEmpty
            ? displayName
            : (fullName.isNotEmpty
                ? fullName
                : (email.isNotEmpty ? email : 'Customer')));
    return _CustomerPreview(
      name: resolvedName,
      phone: phone.isNotEmpty ? phone : null,
      email: email.isNotEmpty ? email : null,
      profilePictureURL: profilePictureURL,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        children: [
          // Item image
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchItemData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                debugPrint('🔍 DEBUG: FutureBuilder ERROR: ${snapshot.error}');
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data ?? {};
              final name = data['name'] as String?;
              final photos = data['photos'] as List<String>?;
              final displayName = (name == 'Rental Item') ? 'Rental Item'.tr() : name;

              if (name == null || name.isEmpty) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text('Rental item not found'.tr()),
                      ],
                    ),
                  ),
                );
              }

              if (photos == null || photos.isEmpty) {
                debugPrint('🔍 DEBUG: FutureBuilder UI - name: $name, but NO PHOTOS FOUND');
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text('No photos available'.tr()),
                      ],
                    ),
                  ),
                );
              }

              debugPrint('🔍 DEBUG: FutureBuilder UI - Success! name: $name, first photo: ${photos.first}');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photos.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('🔍 DEBUG: Image.network ERROR for ${photos.first}: $error');
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.surfaceVariant,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text('Failed to load image'.tr()),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
          // Status card
          _buildStatusCard(context),
          const SizedBox(height: 16),

          _buildSection(
            context,
            title: 'Customer'.tr(),
            children: [
              FutureBuilder<_CustomerPreview>(
                future: _fetchCustomerPreview(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading customer...'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  }

                  final preview = snapshot.data ?? _CustomerPreview(name: 'Customer'.tr());
                  final onSurface = Theme.of(context).colorScheme.onSurface;
                  final onSurfaceMuted = onSurface.withOpacity(0.7);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: preview.profilePictureURL.isNotEmpty
                            ? NetworkImage(preview.profilePictureURL)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: preview.profilePictureURL.isEmpty
                            ? Icon(Icons.person, color: Colors.grey[700])
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview.name == 'Customer' ? 'Customer'.tr() : preview.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (preview.phone != null && preview.phone!.isNotEmpty)
                              Text(
                                preview.phone!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: onSurfaceMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (preview.email != null && preview.email!.isNotEmpty)
                              Text(
                                preview.email!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: onSurfaceMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Booking info
          _buildSection(
            context,
            title: 'Booking Information'.tr(),
            children: [
              _buildInfoRow(
                context,
                'Start'.tr(),
                _formatDateTime(context, booking.startTime),
              ),
              _buildInfoRow(
                context,
                'End'.tr(),
                _formatDateTime(context, booking.endTime),
              ),
              _buildInfoRow(
                context,
                'Duration'.tr(),
                '${booking.quantity} ${_durationUnitLabel(booking.pricingUnit.toString().split('.').last, booking.quantity)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pricing
          _buildSection(
            context,
            title: 'Pricing'.tr(),
            children: [
              _buildInfoRow(context, 'Unit Price'.tr(),
                  '\$${booking.unitPrice.toStringAsFixed(2)}'),
              _buildInfoRow(context, 'Subtotal'.tr(),
                  '\$${booking.subtotal.toStringAsFixed(2)}'),
              if (booking.depositAmount > 0)
                _buildInfoRow(context, 'Deposit'.tr(),
                    '\$${booking.depositAmount.toStringAsFixed(2)}'),
              if (booking.mileageOverageCharge != null &&
                  booking.mileageOverageCharge! > 0)
                _buildInfoRow(
                  context,
                  'Mileage Overage'.tr(),
                  '\$${booking.mileageOverageCharge!.toStringAsFixed(2)}',
                  valueColor: Colors.orange,
                ),
              const Divider(),
              _buildInfoRow(
                context,
                'Total'.tr(),
                '\$${booking.totalAmount.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Vehicle info
          if (booking.startOdometer != null || booking.endOdometer != null) ...[
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Vehicle Information'.tr(),
              children: [
                if (booking.startOdometer != null)
                  _buildInfoRow(context, 'Start Odometer'.tr(),
                      '${booking.startOdometer} km'),
                if (booking.endOdometer != null)
                  _buildInfoRow(
                      context, 'End Odometer'.tr(), '${booking.endOdometer} km'),
                if (booking.totalKilometersDriven != null)
                  _buildInfoRow(context, 'Distance Driven'.tr(),
                      '${booking.totalKilometersDriven} km'),
              ],
            ),
          ],
          
          // Checkout evidence
          if (booking.checkoutEvidence != null) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(
              context,
              'Checkout Evidence'.tr(),
              booking.checkoutEvidence!,
            ),
          ],
          
          // Checkin evidence
          if (booking.checkinEvidence != null) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(
              context,
              'Checkin Evidence'.tr(),
              booking.checkinEvidence!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color statusColor;
    IconData statusIcon;

    switch (booking.status) {
      case RentalBookingStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case RentalBookingStatus.confirmed:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        break;
      case RentalBookingStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.play_circle;
        break;
      case RentalBookingStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      case RentalBookingStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case RentalBookingStatus.disputed:
        statusColor = Colors.purple;
        statusIcon = Icons.warning;
        break;
    }

    return Card(
      color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, size: 40, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedBookingStatus(booking.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (booking.isOverdue)
                    Text(
                      'OVERDUE FOR RETURN'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.red[300] : Colors.red[900],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurfaceMuted,
                ),
          ),
          Text(
            value,
            style: valueStyle ??
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? onSurface,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(
    BuildContext context,
    String title,
    dynamic evidence, // RentalEvidence
  ) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            // TODO: Display evidence media, checklist, damage reports
            Text(
              'Evidence details would be displayed here'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onSurface),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date ${'at'.tr()} $time';
  }

  String _localizedBookingStatus(RentalBookingStatus status) {
    switch (status) {
      case RentalBookingStatus.pending:
        return 'Pending'.tr();
      case RentalBookingStatus.confirmed:
        return 'Confirmed'.tr();
      case RentalBookingStatus.active:
        return 'Active'.tr();
      case RentalBookingStatus.completed:
        return 'Completed'.tr();
      case RentalBookingStatus.cancelled:
        return 'Cancelled'.tr();
      case RentalBookingStatus.disputed:
        return 'Disputed'.tr();
    }
  }

  String _durationUnitLabel(String unit, int quantity) {
    final singular = quantity == 1;
    switch (unit.toLowerCase()) {
      case 'hourly':
        return singular ? 'hour'.tr() : 'hours'.tr();
      case 'daily':
        return singular ? 'day'.tr() : 'days'.tr();
      case 'weekly':
        return singular ? 'week'.tr() : 'weeks'.tr();
      case 'monthly':
        return singular ? 'month'.tr() : 'months'.tr();
      default:
        return unit.tr();
    }
  }
}

class _CustomerPreview {
  final String name;
  final String? phone;
  final String? email;
  final String profilePictureURL;

  const _CustomerPreview({
    required this.name,
    this.phone,
    this.email,
    this.profilePictureURL = '',
  });
}
