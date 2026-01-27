import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatefulWidget {
  final ListingsUser currentUser;
  
  const ContactUsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const String contactPhoneNumber = '+1-868-290-8585';
  static const String contactEmail = 'support@caribtap.com';
  static const String supportChatEmail = 'support@caribtap.com';
  static const String contactAddress = 'CaribTap Support Team\nChase Village, Trinidad and Tobago';
  static const String contactWebsite = 'https://www.caribtap.com';

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      letterSpacing: 1.2,
    );

    final isPremium = (widget.currentUser.isPremium && widget.currentUser.isSubscriptionActive) || widget.currentUser.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Us'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(colorPrimary).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.support_agent, size: 48, color: Color(colorPrimary)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help?'.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Our team is here to assist you with any questions or concerns.'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (isPremium) ...[
              Text('PRIORITY SUPPORT'.tr(), style: titleStyle),
              const SizedBox(height: 12),
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.amber, width: 1.5),
                ),
                child: _buildContactTile(
                  context,
                  title: 'Direct Chat Support'.tr(),
                  subtitle: 'Fast response exclusively for Premium members'.tr(),
                  icon: Icons.chat_bubble_outline,
                  iconColor: Colors.amber,
                  onTap: _openDirectChat,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('GET IN TOUCH'.tr(), style: titleStyle),
            const SizedBox(height: 12),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    context,
                    title: 'Email'.tr(),
                    subtitle: contactEmail,
                    icon: Icons.email_outlined,
                    onTap: () => _launchAction('mailto:$contactEmail?subject=CaribTap Support'),
                  ),
                  const Divider(height: 1, indent: 50),
                  _buildContactTile(
                    context,
                    title: 'Website'.tr(),
                    subtitle: 'www.caribtap.com'.tr(),
                    icon: Icons.language_outlined,
                    onTap: () => _launchAction(contactWebsite),
                  ),
                  const Divider(height: 1, indent: 50),
                  _buildContactTile(
                    context,
                    title: 'Call Us'.tr(),
                    subtitle: contactPhoneNumber,
                    icon: Icons.phone_outlined,
                    onTap: () => _launchAction('tel:$contactPhoneNumber'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('OUR OFFICE'.tr(), style: titleStyle),
            const SizedBox(height: 12),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_outlined, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        contactAddress,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = isDarkMode(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? (isDark ? Colors.white70 : Colors.black54)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _launchAction(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      showAlertDialog(context, 'Error'.tr(), 'Could not perform this action.'.tr());
    }
  }

  void _openDirectChat() {
    _showChatDialog();
  }

  void _showChatDialog() {
    final messageController = TextEditingController();
    final isDark = isDarkMode(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Priority Support'.tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'As a Premium member, your message will be prioritized by our team.'.tr(),
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: messageController,
              maxLines: 4,
              minLines: 3,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Describe your issue...'.tr(),
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(colorPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (messageController.text.isNotEmpty) {
                _sendSupportMessage(messageController.text);
              }
            },
            child: Text('Send Message'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage(String message) async {
    try {
      final subject = 'Priority Support Request - ${widget.currentUser.fullName()}';
      final body = 'User ID: ${widget.currentUser.userID}\n'
                  'Email: ${widget.currentUser.email}\n'
                  'Tier: ${widget.currentUser.subscriptionTier}\n\n'
                  'Message:\n$message';
      
      final url = 'mailto:$supportChatEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      _launchAction(url);
    } catch (e) {
      if (!mounted) return;
      showAlertDialog(context, 'Error'.tr(), 'Failed to send message: $e');
    }
  }
}
