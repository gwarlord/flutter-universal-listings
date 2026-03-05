import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _textController = TextEditingController();
    _initializeEditor();
  }
  
  void _onFocusChanged() {
    if (_hasFocus != _focusNode.hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(DescriptionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText && widget.initialText.isNotEmpty && _isInitialized) {
      _textController.text = widget.initialText;
    }
  }

  Future<void> _initializeEditor() async {
    _prefs = await SharedPreferences.getInstance();
    
    // For new listings (when initialText is empty), clear any stale drafts
    if (widget.initialText.isEmpty) {
      await _prefs.remove(widget.draftKey);
    }
    
    // Set initial text or try to load draft
    if (widget.initialText.isNotEmpty) {
      _textController.text = widget.initialText;
    } else {
      // Only load draft for new listings if one exists (user started and saved a draft)
      final draft = _prefs.getString(widget.draftKey);
      if (draft != null && draft.isNotEmpty) {
        _textController.text = draft;
      }
    }
    
    _textController.addListener(_onTextChanged);
    
    setState(() => _isInitialized = true);
  }

  Future<void> _saveDraft() async {
    await _prefs.setString(widget.draftKey, _textController.text);
    debugPrint('[DescriptionEditor] Draft auto-saved');
  }
  
  Future<void> _saveDraftWithFeedback() async {
    await _prefs.setString(widget.draftKey, _textController.text);
    debugPrint('[DescriptionEditor] Draft saved manually');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _clearDraft() async {
    await _prefs.remove(widget.draftKey);
    debugPrint('[DescriptionEditor] Draft cleared');
  }

  void _onTextChanged() {
    widget.onChanged(_textController.text);
    // Auto-save draft every 3 seconds of inactivity
    _autoSaveDraft();
  }

  Timer? _autoSaveTimer;
  
  void _autoSaveDraft() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveDraft();
    });
  }

  /// Calculate character count from current text
  int get _charCount => _textController.text.length;
  
  /// Calculate word count from current text
  int get _wordCount {
    final text = _textController.text;
    return text.trim().isEmpty 
        ? 0 
        : text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    // Compute counts on-the-fly - no setState() needed
    final charCount = _charCount;
    final wordCount = _wordCount;
    final isNearLimit = charCount > widget.maxCharacters * 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),

        // Text Input Field
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasFocus 
                  ? primaryColor 
                  : Colors.grey.withOpacity(0.3),
              width: _hasFocus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.grey.shade900 : Colors.white,
          ),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 5,
            maxLength: widget.maxCharacters,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Write a clear and detailed description...',
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              counterText: '', // Hide default counter
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Stats and Progress Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;

            final statsText = Text(
              'Words: $wordCount  •  Characters: $charCount/${widget.maxCharacters}',
              style: TextStyle(
                fontSize: 12,
                color: isNearLimit ? Colors.orange : Colors.grey,
                fontWeight: isNearLimit ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: isCompact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            );

            final progressBar = SizedBox(
              width: isCompact ? double.infinity : 110,
              child: Tooltip(
                message: '${(charCount / widget.maxCharacters * 100).toStringAsFixed(0)}% used',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: charCount / widget.maxCharacters,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isNearLimit ? Colors.orange : primaryColor,
                    ),
                  ),
                ),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statsText,
                  const SizedBox(height: 6),
                  progressBar,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: statsText),
                const SizedBox(width: 10),
                progressBar,
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save Draft'),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _saveDraftWithFeedback,
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                            _textController.clear();
                            _clearDraft();
                            Navigator.pop(context);
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
        ),
      ],
    );
  }
}
