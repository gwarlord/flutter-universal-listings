import 'package:flutter/material.dart';
import '../../model/rental_unit.dart';
import '../../services/rental_service.dart';
import 'rental_unit_editor_screen.dart';

class RentalInventoryScreen extends StatefulWidget {
  final String listingId;
  final String listingTitle;

  const RentalInventoryScreen({
    Key? key,
    required this.listingId,
    required this.listingTitle,
  }) : super(key: key);

  @override
  State<RentalInventoryScreen> createState() => _RentalInventoryScreenState();
}

class _RentalInventoryScreenState extends State<RentalInventoryScreen> {
  final RentalService _rentalService = RentalService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rental Inventory'),
        subtitle: Text(widget.listingTitle),
      ),
      body: StreamBuilder<List<RentalUnit>>(
        stream: _rentalService.getRentalUnits(widget.listingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final units = snapshot.data ?? [];

          if (units.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No rental units yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add units to start renting out this listing',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: units.length,
            itemBuilder: (context, index) {
              return _buildUnitCard(units[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
    );
  }

  Widget _buildUnitCard(RentalUnit unit) {
    Color statusColor;
    IconData statusIcon;

    switch (unit.status) {
      case RentalUnitStatus.available:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case RentalUnitStatus.rented:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case RentalUnitStatus.maintenance:
        statusColor = Colors.red;
        statusIcon = Icons.build;
        break;
      case RentalUnitStatus.unavailable:
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToEditor(unit: unit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Unit photo or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: unit.photoUrls.isNotEmpty
                    ? Image.network(
                        unit.photoUrls.first,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPhotoPlaceholder();
                        },
                      )
                    : _buildPhotoPlaceholder(),
              ),
              const SizedBox(width: 16),
              // Unit info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (unit.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        unit.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (unit.licensePlate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.directions_car,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            unit.licensePlate!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          unit.status.toString().split('.').last.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, unit),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: Icon(
        Icons.image,
        size: 40,
        color: Colors.grey[500],
      ),
    );
  }

  void _handleMenuAction(String action, RentalUnit unit) {
    switch (action) {
      case 'edit':
        _navigateToEditor(unit: unit);
        break;
      case 'delete':
        _confirmDelete(unit);
        break;
    }
  }

  void _confirmDelete(RentalUnit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete "${unit.unitName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rentalService.deleteRentalUnit(
                  widget.listingId, unit.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unit deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditor({RentalUnit? unit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalUnitEditorScreen(
          listingId: widget.listingId,
          unit: unit,
        ),
      ),
    );
  }
}
