import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/services/menu_service.dart';
import 'package:caribtap/models/menu_models.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'menu_section_editor_screen.dart';

class MenuBuilderScreen extends StatefulWidget {
  final ListingModel listing;

  const MenuBuilderScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<MenuBuilderScreen> createState() => _MenuBuilderScreenState();
}

class _MenuBuilderScreenState extends State<MenuBuilderScreen> {
  late List<MenuSection> _sections;
  final MenuService _menuService = MenuService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sections = widget.listing.menuSections
        .map((e) => MenuSection.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> _addSection() async {
    final sectionTitle = await _showAddSectionDialog();
    if (sectionTitle != null && sectionTitle.trim().isNotEmpty) {
      setState(() {
        _sections.add(
          MenuSection(
            id: const Uuid().v4(),
            title: sectionTitle.trim(),
            sortOrder: _sections.length,
            items: [],
          ),
        );
      });
    }
  }

  Future<void> _editSection(int index) async {
    final result = await Navigator.push<MenuSection>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuSectionEditorScreen(
          listing: widget.listing,
          section: _sections[index],
          sectionIndex: index,
        ),
      ),
    );
    if (result != null) {
      setState(() => _sections[index] = result);
    }
  }

  Future<void> _deleteSection(int index) async {
    final dark = isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Delete Section?',
          style: TextStyle(color: dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete "${_sections[index].title}" and all its items. This action cannot be undone.',
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: dark ? Colors.grey : Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _sections.removeAt(index));
    }
  }

  Future<void> _saveSections() async {
    setState(() => _isSaving = true);
    try {
      // Update sort order based on current list order
      for (int i = 0; i < _sections.length; i++) {
        _sections[i] = _sections[i].copyWith(sortOrder: i);
      }

      await _menuService.updateMenuSections(
        widget.listing.id,
        _sections.map((s) => s.toJson()).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Menu saved successfully!'),
            backgroundColor: Color(cfg.colorPrimary),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showAddSectionDialog() async {
    final controller = TextEditingController();
    final dark = isDarkMode(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Add New Section',
          style: TextStyle(color: dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: dark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'e.g., Main Courses, Drinks',
            hintStyle: TextStyle(color: dark ? Colors.grey.shade500 : Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: dark ? Colors.black26 : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: dark ? Colors.grey : Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) return false;
        return true;
      },
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Digital Menu Builder', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: dark ? Colors.black : Colors.white,
          foregroundColor: dark ? Colors.white : Colors.black,
          actions: [
            if (_sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _saveSections,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_sections.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: primaryColor.withOpacity(0.05),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Drag and drop sections to reorder them.',
                        style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _sections.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _sections.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final section = _sections.removeAt(oldIndex);
                          _sections.insert(newIndex, section);
                        });
                      },
                      itemBuilder: (context, index) {
                        final section = _sections[index];
                        return _buildSectionCard(context, section, index);
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _addSection,
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add Section', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final dark = isDarkMode(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(cfg.colorPrimary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Color(cfg.colorPrimary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Build Your Digital Menu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Organize your dishes into sections like "Appetizers", "Main Course", or "Desserts".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _addSection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(cfg.colorPrimary),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: const Text('Create First Section', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    MenuSection section,
    int index,
  ) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    return Card(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      color: dark ? Colors.grey.shade900 : Colors.white,
      child: InkWell(
        onTap: () => _editSection(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: dark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.layers_outlined, size: 14, color: dark ? Colors.grey : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${section.items.length} item${section.items.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: dark ? Colors.grey.shade700 : Colors.grey.shade400),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteSection(index);
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.more_vert,
                      color: dark ? Colors.grey.shade500 : Colors.grey.shade600),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator,
                      color: dark ? Colors.grey.shade700 : Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on MenuSection {
  MenuSection copyWith({
    String? id,
    String? title,
    int? sortOrder,
    List<MenuItem>? items,
  }) {
    return MenuSection(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      items: items ?? this.items,
    );
  }
}
