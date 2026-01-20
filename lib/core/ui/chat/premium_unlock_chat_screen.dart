import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/subscription/paywall_screen.dart';

class PremiumUnlockChatScreen extends StatelessWidget {
  final ListingsUser currentUser;

  const PremiumUnlockChatScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      // Lock Icon with Premium Badge
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(colorPrimary).withOpacity(0.1),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(colorPrimary).withOpacity(0.2),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 50,
                              color: Color(colorPrimary),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PREMIUM',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Direct Messaging',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // Description
                      Text(
                        'Connect directly with sellers and buyers through real-time messaging.',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // Feature List
                      _buildFeatureItem(
                        Icons.message,
                        'Real-time Messaging',
                        'Instant chat with other users',
                        isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        Icons.image,
                        'Media Sharing',
                        'Share images, videos & audio',
                        isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        Icons.groups,
                        'Group Conversations',
                        'Chat with multiple users at once',
                        isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        Icons.notifications_active,
                        'Push Notifications',
                        'Never miss a message',
                        isDark,
                      ),

                      const SizedBox(height: 32),

                      // Upgrade Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(colorPrimary),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaywallScreen(
                                  currentUser: currentUser,
                                ),
                              ),
                            );
                            if (result == true && context.mounted) {
                              // User upgraded, close this screen
                              Navigator.pop(context);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.workspace_premium, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Upgrade to Premium'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Learn More Link
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaywallScreen(
                                currentUser: currentUser,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Learn more about Premium features'.tr(),
                          style: TextStyle(
                            color: Color(colorPrimary),
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, bool isDark) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(colorPrimary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(colorPrimary),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
