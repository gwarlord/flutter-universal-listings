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
  // 📝 EDIT THESE VALUES TO UPDATE YOUR CONTACT INFORMATION
  // ============================================================
  static const String contactPhoneNumber = '+1-868-290-8585';
  static const String contactEmail = 'support@caribtap.com';
  static const String supportChatEmail = 'support@caribtap.com';
  static const String contactAddress = 'CaribTap Support Team\nChase Village, Trinidad and Tobago';
  static const String contactWebsite = 'https://www.caribtap.com';
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Admins get access to everything, plus premium subscribers
    final isPremium = (widget.currentUser.isPremium && widget.currentUser.isSubscriptionActive) || widget.currentUser.isAdmin;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(colorPrimary),
        iconTheme: IconThemeData(
            color: isDarkMode(context) ? Colors.grey.shade200 : Colors.white),
        title: Text(
          'Contact Us',
          style: TextStyle(
              color: isDarkMode(context) ? Colors.grey.shade200 : Colors.white,
              fontWeight: FontWeight.bold),
        ).tr(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Material(
              elevation: 2,
              color: isDarkMode(context) ? Colors.black54 : Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Section
                  Padding(
                    padding:
                        const EdgeInsets.only(right: 16.0, left: 16, top: 16),
                    child: Text(
                      'Our Address',
                      style: TextStyle(
                          color:
                              isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ).tr(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 16.0, left: 16, top: 8, bottom: 16),
                    child: Text(
                      contactAddress,
                      style: TextStyle(
                        color: isDarkMode(context)
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Email Section
                  ListTile(
                    onTap: () async {
                      var url =
                          'mailto:$contactEmail?subject=CaribTap Support';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      } else {
                        if (!mounted) return;
                        showAlertDialog(context, 'Couldn\'t send email'.tr(),
                            'There is no mailing app installed'.tr());
                      }
                    },
                    title: Text(
                      'Email',
                      style: TextStyle(
                          color:
                              isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      contactEmail,
                      style: TextStyle(
                        color: isDarkMode(context)
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    trailing: Icon(
                      Icons.mail_outline,
                      color:
                          isDarkMode(context) ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  // Website Section
                  ListTile(
                    onTap: () async {
                      if (await canLaunchUrl(Uri.parse(contactWebsite))) {
                        await launchUrl(Uri.parse(contactWebsite));
                      }
                    },
                    title: Text(
                      'Website',
                      style: TextStyle(
                          color:
                              isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      contactWebsite,
                      style: TextStyle(
                        color: isDarkMode(context)
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    trailing: Icon(
                      Icons.language_outlined,
                      color:
                          isDarkMode(context) ? Colors.white54 : Colors.black54,
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

  void _openDirectChat() {
    // Show a chat-like dialog to compose message to support
    _showChatDialog();
  }

  void _showChatDialog() {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Support'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a message to our support team'.tr(),
              style: TextStyle(
                color: isDarkMode(context) ? Colors.grey[300] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your message...'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDarkMode(context) ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (messageController.text.isNotEmpty) {
                _sendSupportMessage(messageController.text);
              }
            },
            child: Text('Send'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSupportMessage(String message) async {
    try {
      final subject = 'Support Request - ${widget.currentUser.fullName()}';
      final body = Uri.encodeComponent(
        'User ID: ${widget.currentUser.userID}\n'
        'Email: ${widget.currentUser.email}\n\n'
        'Message:\n$message'
      );
      final url = 'mailto:$supportChatEmail?subject=${Uri.encodeComponent(subject)}&body=$body';
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (!mounted) return;
        showAlertDialog(context, 'Couldn\'t send message'.tr(),
            'There is no email app installed'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      showAlertDialog(context, 'Error'.tr(), 'Failed to send message: $e');
    }
  }
}
