import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DescriptionEditor extends StatefulWidget {
  final String initialText;
  final Function(String) onChanged;
  final int maxCharacters;
  final String draftKey;

  const DescriptionEditor({
    Key? key,
    this.initialText = '',
    required this.onChanged,
    this.maxCharacters = 2000,
    required this.draftKey,
  }) : super(key: key);

  @override
  State<DescriptionEditor> createState() => _DescriptionEditorState();
}

class _DescriptionEditorState extends State<DescriptionEditor> {
  late quill.QuillController _quillController;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  int _charCount = 0;
  int _wordCount = 0;
  bool _showPreview = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _initializeEditor();
    _loadDraft();
  }

  @override
  void didUpdateWidget(DescriptionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If initialText changed (e.g., during edit mode data loading), reinitialize
    if (oldWidget.initialText != widget.initialText && widget.initialText.isNotEmpty) {
      final preview = widget.initialText.length > 50 
          ? widget.initialText.substring(0, 50) 
          : widget.initialText;
      debugPrint('[DescriptionEditor] initialText changed, reinitializing with: $preview...');
      _initializeEditor();
    }
  }

  Future<void> _initializeEditor() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize with initial text or empty document
    late final quill.Document document;
    
    if (widget.initialText.isNotEmpty) {
      try {
        // Try to parse as JSON (rich text format)
        document = quill.Document.fromJson(jsonDecode(widget.initialText));
      } catch (e) {
        // Fall back to plain text if JSON parsing fails
        debugPrint('[DescriptionEditor] JSON parse failed, using plain text: $e');
        document = quill.Document()
          ..insert(0, widget.initialText);
      }
    } else {
      document = quill.Document();
    }

    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _quillController.addListener(_onTextChanged);
    _updateCounts();
  }

  Future<void> _loadDraft() async {
    final draft = _prefs.getString(widget.draftKey);
    if (draft != null && draft.isNotEmpty) {
      try {
        final document = quill.Document.fromJson(jsonDecode(draft));
        _quillController.document = document;
        _updateCounts();
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  Future<void> _saveDraft() async {
    final jsonData = jsonEncode(_quillController.document.toDelta().toJson());
    await _prefs.setString(widget.draftKey, jsonData);
    debugPrint('[DescriptionEditor] Draft saved');
  }

  Future<void> _clearDraft() async {
    await _prefs.remove(widget.draftKey);
    debugPrint('[DescriptionEditor] Draft cleared');
  }

  void _onTextChanged() {
    _updateCounts();
    final plainText = _quillController.document.toPlainText();
    widget.onChanged(plainText);
    _saveDraft();
  }

  void _updateCounts() {
    final plainText = _quillController.document.toPlainText();
    setState(() {
      _charCount = plainText.length;
      _wordCount = plainText.trim().isEmpty 
          ? 0 
          : plainText.trim().split(RegExp(r'\s+')).length;
    });
  }

  String _getPlainText() {
    return _quillController.document.toPlainText();
  }

  @override
  void dispose() {
    _quillController.removeListener(_onTextChanged);
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              icon: Icon(_showPreview ? Icons.edit : Icons.preview),
              label: Text(_showPreview ? 'Edit' : 'Preview'),
              onPressed: () {
                setState(() => _showPreview = !_showPreview);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Editor or Preview
        if (!_showPreview)
          _buildEditor(isDark, primaryColor)
        else
          _buildPreview(isDark),

        const SizedBox(height: 12),

        // Stats Row
        _buildStatsRow(primaryColor),

        const SizedBox(height: 8),

        // Draft Actions
        _buildDraftActions(primaryColor),
      ],
    );
  }

  Widget _buildEditor(bool isDark, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDark ? Colors.grey.shade900 : Colors.white,
      ),
      child: Column(
        children: [
          // Toolbar
          quill.QuillSimpleToolbar(
            controller: _quillController,
            config: quill.QuillSimpleToolbarConfig(
              toolbarSectionSpacing: 4,
              multiRowsDisplay: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showFontFamily: false,
              showFontSize: false,
              showHeaderStyle: true,
              showInlineCode: true,
              showLink: true,
              showLeftAlignment: false,
              showRightAlignment: false,
              showCenterAlignment: false,
              showJustifyAlignment: false,
              showCodeBlock: false,
              showQuote: true,
            ),
          ),
          const Divider(height: 1),

          // Editor with constraints
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 180,
              maxHeight: 300,
            ),
            child: GestureDetector(
              onTap: () {
                _focusNode.requestFocus();
              },
              child: quill.QuillEditor(
                controller: _quillController,
                scrollController: _scrollController,
                focusNode: _focusNode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    final plainText = _getPlainText();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Text(
          plainText.isEmpty ? 'No description yet...' : plainText,
          style: TextStyle(
            fontSize: 14,
            color: plainText.isEmpty 
                ? Colors.grey 
                : isDark ? Colors.white : Colors.black87,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Color primaryColor) {
    final charPercentage = (_charCount / widget.maxCharacters * 100).toStringAsFixed(0);
    final isNearLimit = _charCount > widget.maxCharacters * 0.8;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Words: $_wordCount  •  Characters: $_charCount/${widget.maxCharacters}',
          style: TextStyle(
            fontSize: 12,
            color: isNearLimit ? Colors.orange : Colors.grey,
            fontWeight: isNearLimit ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        SizedBox(
          width: 60,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _charCount / widget.maxCharacters,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearLimit ? Colors.orange : primaryColor,
                ),
                backgroundColor: Colors.grey.shade300,
              ),
              Text(
                '$charPercentage%',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDraftActions(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: _saveDraft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Description'),
                  content: const Text('This will clear all text and delete the draft. Continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _quillController.clear();
                        _clearDraft();
                        Navigator.pop(context);
                        _updateCounts();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
