import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/models/menu_models.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'menu_item_editor_screen.dart';

class MenuSectionEditorScreen extends StatefulWidget {
  final ListingModel listing;
  final MenuSection section;
  final int sectionIndex;

  const MenuSectionEditorScreen({
    Key? key,
    required this.listing,
    required this.section,
    required this.sectionIndex,
  }) : super(key: key);

  @override
  State<MenuSectionEditorScreen> createState() => _MenuSectionEditorScreenState();
}

class _MenuSectionEditorScreenState extends State<MenuSectionEditorScreen> {
  late String _sectionTitle;
  late List<MenuItem> _items;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _sectionTitle = widget.section.title;
    _items = List.from(widget.section.items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _titleController = TextEditingController(text: _sectionTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final result = await Navigator.push<MenuItem>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuItemEditorScreen(
          listing: widget.listing,
          item: null,
          currencyCode: widget.listing.menuCurrencyCode,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final newItem = result.copyWith(sortOrder: _items.length);
        _items.add(newItem);
      });
    }
  }

  Future<void> _editItem(int index) async {
    final result = await Navigator.push<MenuItem>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuItemEditorScreen(
          listing: widget.listing,
          item: _items[index],
          currencyCode: widget.listing.menuCurrencyCode,
        ),
      ),
    );
    if (result != null) {
      setState(() => _items[index] = result);
    }
  }

  Future<void> _deleteItem(int index) async {
    final dark = isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Delete Item?',
          style: TextStyle(color: dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${_items[index].name}" from this section?',
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
      setState(() => _items.removeAt(index));
    }
  }

  void _saveSectionChanges() {
    // Update sort order for all items before saving
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(sortOrder: i);
    }

    final updatedSection = widget.section.copyWith(
      title: _sectionTitle.trim().isEmpty ? 'Untitled Section' : _sectionTitle.trim(),
      items: _items,
    );
    Navigator.pop(context, updatedSection);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit Section', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: dark ? Colors.black : Colors.white,
        foregroundColor: dark ? Colors.white : Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton(
              onPressed: _saveSectionChanges,
              style: TextButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? Colors.black : Colors.white,
              border: Border(bottom: BorderSide(color: dark ? Colors.white12 : Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SECTION TITLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g., Breakfast Specials',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => setState(() => _sectionTitle = value),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'ITEMS (${_items.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Hold & drag to reorder',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemCard(context, item, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    final dark = isDarkMode(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_outlined, size: 64, color: dark ? Colors.grey.shade800 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'This section is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first item to "${_sectionTitle.isEmpty ? 'this section' : _sectionTitle}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, MenuItem item, int index) {
    final dark = isDarkMode(context);
    final currencySymbol = _getCurrencySymbol(item.currencyCode);
    final primaryColor = Color(cfg.colorPrimary);

    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      color: dark ? Colors.grey.shade900 : Colors.white,
      child: InkWell(
        onTap: () => _editItem(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.photos.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.photos.first.url,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70,
                      height: 70,
                      color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported_outlined, size: 24),
                    ),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fastfood_outlined, color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: dark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$currencySymbol${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: dark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                    if (!item.isAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Sold Out',
                            style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteItem(index);
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Item', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    child: Icon(Icons.more_vert,
                        color: dark ? Colors.grey.shade600 : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator,
                        color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrencySymbol(String currencyCode) {
    const symbols = {
      'USD': r'$',
      'XCD': r'$',
      'JMD': r'$',
      'TTD': r'$',
      'BSD': r'$',
      'BBD': r'$',
      'GYD': r'$',
      'HTG': 'G',
      'DOP': r'$',
      'KYD': r'$',
      'ANG': 'ƒ',
      'SRD': r'$',
      'XOF': 'CFA',
      'EUR': '€',
      'GBP': '£',
    };
    return symbols[currencyCode] ?? currencyCode;
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

extension on MenuItem {
  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currencyCode,
    List<MenuItemPhoto>? photos,
    List<String>? tags,
    bool? isAvailable,
    int? sortOrder,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currencyCode: currencyCode ?? this.currencyCode,
      photos: photos ?? this.photos,
      tags: tags ?? this.tags,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
