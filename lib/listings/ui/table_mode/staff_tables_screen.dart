import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/api/firebase/table_mode_firebase.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/table_mode_models.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class StaffTablesScreen extends StatefulWidget {
  final ListingModel listing;
  final User currentUser;

  const StaffTablesScreen({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<StaffTablesScreen> createState() => _StaffTablesScreenState();
}

class _StaffTablesScreenState extends State<StaffTablesScreen> {
  final _repository = tableModeRepository;
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tables = await _repository.getTables(listingId: widget.listing.id);
      setState(() {
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Load tables error: $e');
    }
  }

  Future<void> _addTable() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _TableNameDialog(),
    );

    if (name == null || name.isEmpty) return;

    showProgress(context, 'Creating table...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.upsertTable(
        listingId: widget.listing.id,
        tableName: name,
      );

      hideProgress();
      showSnackBar(context, 'Table created successfully!'.tr());
      _loadTables();
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _editTable(TableModel table) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _TableNameDialog(initialName: table.tableName),
    );

    if (name == null || name.isEmpty) return;

    showProgress(context, 'Updating table...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.upsertTable(
        listingId: widget.listing.id,
        tableId: table.tableId,
        tableName: name,
        tableCodePublic: table.tableCodePublic,
      );

      hideProgress();
      showSnackBar(context, 'Table updated successfully!'.tr());
      _loadTables();
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _toggleTableStatus(TableModel table) async {
    final newStatus = !table.isActive;

    showProgress(context, 'Updating table...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.deactivateTable(
        listingId: widget.listing.id,
        tableId: table.tableId,
        isActive: newStatus,
      );

      hideProgress();
      showSnackBar(
        context,
        newStatus ? 'Table activated'.tr() : 'Table deactivated'.tr(),
      );
      _loadTables();
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _viewTableQR(TableModel table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TableQRScreen(
          listing: widget.listing,
          table: table,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tables & QR Codes'.tr()),
        backgroundColor: Color(colorPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? _buildEmptyState()
              : _buildTablesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        icon: const Icon(Icons.add),
        label: Text('Add Table'.tr()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_restaurant,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No tables yet'.tr(),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first table'.tr(),
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesList() {
    final isDark = isDarkMode(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final table = _tables[index];
        return Card(
          color: isDark ? Colors.grey[900] : Colors.white,
          shadowColor: isDark ? Colors.black54 : Colors.black12,
          elevation: isDark ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: table.isActive ? Colors.green : Colors.grey,
              child: Text(
                table.tableCodePublic,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              table.tableName,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              table.isActive ? 'Active'.tr() : 'Inactive'.tr(),
              style: TextStyle(
                color: table.isActive
                    ? Colors.green
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            trailing: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: isDark ? Colors.black54 : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'qr':
                      _viewTableQR(table);
                      break;
                    case 'edit':
                      _editTable(table);
                      break;
                    case 'toggle':
                      _toggleTableStatus(table);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'View QR Code'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Edit'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          table.isActive ? Icons.block : Icons.check_circle,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          table.isActive ? 'Deactivate'.tr() : 'Activate'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _viewTableQR(table),
          ),
        );
      },
    );
  }
}

// ============================================================================
// TABLE NAME DIALOG
// ============================================================================

class _TableNameDialog extends StatefulWidget {
  final String? initialName;

  const _TableNameDialog({this.initialName});

  @override
  State<_TableNameDialog> createState() => _TableNameDialogState();
}

class _TableNameDialogState extends State<_TableNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        widget.initialName == null ? 'Add Table'.tr() : 'Edit Table'.tr(),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: 'Table Name'.tr(),
          hintText: 'e.g., Table 7'.tr(),
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Color(colorPrimary),
              width: 1.5,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel'.tr(),
            style: TextStyle(
              color: Color(colorPrimary),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(
            'Save'.tr(),
            style: TextStyle(
              color: Color(colorPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TABLE QR SCREEN
// ============================================================================

class _TableQRScreen extends StatelessWidget {
  final ListingModel listing;
  final TableModel table;

  const _TableQRScreen({
    required this.listing,
    required this.table,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final qrData = table.generateQRPayload(listing.id);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(table.tableName),
        backgroundColor: Color(colorPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareQR(context, qrData),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              table.tableName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Table Code: ${table.tableCodePublic}'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 300,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            // Save QR image button
            OutlinedButton.icon(
              onPressed: () => _saveQRImage(context, qrData),
              icon: const Icon(Icons.download_rounded),
              label: Text('Save QR Image'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: isDark ? Colors.grey[900] : Colors.white,
              shadowColor: isDark ? Colors.black54 : Colors.black12,
              elevation: isDark ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Print or display this QR code on the table'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2. Customers can scan to join the table session'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3. Or customers can manually enter: ${table.tableCodePublic}'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQRImage(BuildContext context, String qrData) async {
    try {
      final painter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final uiImage = await painter.toImage(1024);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        showSnackBar(context, 'Could not generate QR image'.tr());
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final safeName = 'table_${table.tableName}_${DateTime.now().millisecondsSinceEpoch}'
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

      await Gal.putImageBytes(bytes, album: 'CaribTap');
      showSnackBar(context, 'QR image saved to gallery'.tr());
    } catch (e) {
      debugPrint('Save QR error: $e');
      if (e is GalException) {
        if (e.type == GalExceptionType.accessDenied) {
          showSnackBar(context, 'Storage permission required'.tr());
        } else {
          showSnackBar(context, 'Failed to save QR image: ${e.type}'.tr());
        }
      } else {
        showSnackBar(context, 'Failed to save QR image'.tr());
      }
    }
  }

  Future<void> _shareQR(BuildContext context, String qrData) async {
    try {
      await Share.share(
        'Join ${table.tableName} at ${listing.title}\n\nTable Code: ${table.tableCodePublic}\n\nOr scan QR: $qrData',
        subject: '${table.tableName} - ${listing.title}',
      );
    } catch (e) {
      showSnackBar(context, 'Failed to share'.tr());
    }
  }
}
