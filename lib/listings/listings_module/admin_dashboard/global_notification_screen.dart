import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';

// Quick-fill templates
typedef _Preset = ({String label, String title, String body});

const List<_Preset> _presets = [
  (
    label: 'Maintenance',
    title: 'Scheduled Maintenance',
    body:
        'The app will be briefly unavailable for maintenance. We appreciate your patience.',
  ),
  (
    label: 'New Feature',
    title: "What's New",
    body: 'We just released a new feature! Open the app to check it out.',
  ),
  (
    label: 'Promotion',
    title: 'Special Offer',
    body:
        'A limited-time promotion is now available. Open the app to learn more.',
  ),
  (
    label: 'Reminder',
    title: 'Friendly Reminder',
    body: "Just a reminder to check out what's happening on the platform!",
  ),
];

class GlobalNotificationScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const GlobalNotificationScreen({super.key, required this.currentUser});

  @override
  State<GlobalNotificationScreen> createState() =>
      _GlobalNotificationScreenState();
}

class _GlobalNotificationScreenState extends State<GlobalNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  /// 'topic' uses FCM topic broadcast; 'all' batches direct multicast.
  String _targetMode = 'topic';
  bool _isSending = false;
  String? _lastResult;
  bool _lastResultIsError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyPreset(_Preset preset) {
    setState(() {
      _titleController.text = preset.title;
      _bodyController.text = preset.body;
      _lastResult = null;
    });
  }

  Future<void> _sendNotification({required bool testOnly}) async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          testOnly
              ? 'Send test notification?'.tr()
              : 'Send global notification?'.tr(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!testOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This will push a notification to ALL users.'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            Text('${'Title'.tr()}: $title'),
            const SizedBox(height: 4),
            Text('${'Body'.tr()}: $body'),
            const SizedBox(height: 4),
            if (testOnly)
              Text('Recipient: you only'.tr())
            else
              Text(
                '${'Mode'.tr()}: ${_targetMode == 'topic' ? 'Topic broadcast' : 'Direct multicast'}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: testOnly
                ? null
                : ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
            child: Text(testOnly ? 'Send test'.tr() : 'Send to all'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
      _lastResult = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendGlobalNotification');

      final result = await callable.call(<String, dynamic>{
        'title': title,
        'body': body,
        'targetMode': testOnly ? 'self' : _targetMode,
        'extraData': <String, String>{},
      });

      final data = result.data as Map;
      final count = data['recipientCount'];
      final countLabel =
          count == -1 ? 'sent via topic broadcast' : 'sent to $count device(s)';

      setState(() {
        _lastResult =
            testOnly ? 'Test notification dispatched.'.tr() : 'Notification $countLabel.';
        _lastResultIsError = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _lastResult = 'Error: ${e.message ?? e.code}';
        _lastResultIsError = true;
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Unexpected error: $e';
        _lastResultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Global Notification'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Result banner
              if (_lastResult != null)
                _ResultBanner(
                  message: _lastResult!,
                  isError: _lastResultIsError,
                ),

              // Quick presets
              Text(
                'Quick presets'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets
                    .map((p) => ActionChip(
                          label: Text(p.label),
                          onPressed: () => _applyPreset(p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Title field
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: 'Title'.tr(),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'.tr()
                    : null,
              ),
              const SizedBox(height: 16),

              // Body field
              TextFormField(
                controller: _bodyController,
                maxLength: 240,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Body'.tr(),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Body is required'.tr()
                    : null,
              ),
              const SizedBox(height: 20),

              // Delivery mode
              Text(
                'Delivery mode'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              _ModeCard(
                value: 'topic',
                groupValue: _targetMode,
                title: 'Topic broadcast',
                subtitle:
                    'Fastest. Reaches all devices subscribed to all_users. '
                    'Recommended for most broadcasts.',
                onChanged: (v) => setState(() => _targetMode = v!),
              ),
              const SizedBox(height: 8),
              _ModeCard(
                value: 'all',
                groupValue: _targetMode,
                title: 'Direct multicast',
                subtitle:
                    'Queries every user token and sends in batches of 499. '
                    'Use if some users may not have the topic subscription yet.',
                onChanged: (v) => setState(() => _targetMode = v!),
              ),
              const SizedBox(height: 28),

              // Action buttons
              if (_isSending)
                const Center(child: CircularProgressIndicator())
              else ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.science_outlined),
                  label: Text('Send test to me'.tr()),
                  onPressed: () => _sendNotification(testOnly: true),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text('Send to all users'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _sendNotification(testOnly: false),
                ),
              ],

              const SizedBox(height: 32),

              // Recent history
              _NotificationHistory(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ResultBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _ResultBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<String?> onChanged;

  const _ModeCard({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationHistory extends StatelessWidget {
  final bool isDark;

  const _NotificationHistory({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent broadcasts'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('adminNotifications')
              .orderBy('sentAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Text(
                'No broadcasts yet.'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                  fontSize: 13,
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final sentAt = d['sentAt'];
                String dateLabel = '';
                if (sentAt is Timestamp) {
                  dateLabel = DateFormat('MMM d, y HH:mm').format(sentAt.toDate());
                }
                final count = d['recipientCount'];
                final countLabel = count == -1 ? 'topic' : '$count devices';
                return ListTile(
                  dense: true,
                  title: Text(
                    d['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${d['body'] ?? ''}\n$dateLabel · $countLabel',
                  ),
                  isThreeLine: true,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
