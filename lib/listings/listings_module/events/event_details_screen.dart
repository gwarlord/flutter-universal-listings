import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/event_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:caribtap/listings/listings_module/home/home_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_module/events/create_event_screen.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:caribtap/listings/ui/share/promote_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventModel event;

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);
    final endDate = DateTime.fromMillisecondsSinceEpoch(event.endAtSeconds * 1000);
    final primaryColor = Color(cfg.colorPrimary);
    final currentUser = context.read<AuthenticationBloc>().user;
    final isOwner = currentUser?.userID == event.createdBy;
    final isAdmin = currentUser?.isAdmin ?? false;
    final isEventFav = currentUser?.likedEventsIDs.contains(event.id) ?? false;
    event.isFav = isEventFav;

    return Theme(
      data: Theme.of(context).copyWith(
        // Force the PopupMenu theme to handle dark mode colors correctly
        cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          textStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
      ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Header with Image
            SliverAppBar(
              expandedHeight: 350.0,
              pinned: true,
              actions: [
                if (currentUser != null)
                  IconButton(
                    icon: Icon(
                      isEventFav ? Icons.favorite : Icons.favorite_border,
                      color: isEventFav ? primaryColor : Colors.white,
                    ),
                    onPressed: () => _toggleFavoriteEvent(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareEvent(),
                ),
                if (isOwner || isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editEvent(context);
                      } else if (value == 'delete') {
                        _deleteEvent(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit, color: isDark ? Colors.white70 : Colors.black54),
                          title: Text('Edit'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white),
                    onPressed: () => _reportEvent(context),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onTap: () {
                    if (event.posterImageUrl.trim().isNotEmpty) {
                      push(context, FullScreenImageViewer(
                        imageUrl: event.posterImageUrl,
                      ));
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (event.posterImageUrl.trim().isNotEmpty)
                        Hero(
                          tag: event.posterImageUrl,
                          child: Image.network(
                            event.posterImageUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                          child: Icon(Icons.event, size: 80, color: primaryColor),
                        ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black26,
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black87,
                              ],
                              stops: [0.0, 0.3, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),

            // Content
            SliverToBoxAdapter(
              child: Container(
                transform: Matrix4.translationValues(0, -30, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),

                    // Event Title & Committee
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                            height: 1.2,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (event.committee.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${'by'.tr()} ${event.committee}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Info Cards
                    _buildDetailedInfoRow(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: DateFormat('EEEE, MMMM d, y').format(startDate),
                      subtitle: '${DateFormat('h:mm a').format(startDate)} - ${DateFormat('h:mm a').format(endDate)}',
                    ),
                    const SizedBox(height: 16),
                    _buildDetailedInfoRow(
                      context,
                      icon: Icons.place_rounded,
                      title: event.venueName,
                      subtitle: event.countryCode,
                      trailing: IconButton(
                        icon: Icon(Icons.navigation_rounded, color: primaryColor),
                        onPressed: () => _openMap(event.latitude, event.longitude),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Social Links Row
                    if (event.facebookUrl.isNotEmpty || event.instagramUrl.isNotEmpty) ...[
                      Row(
                        children: [
                          if (event.facebookUrl.isNotEmpty)
                            _socialButton(
                              icon: FontAwesomeIcons.facebook,
                              color: const Color(0xFF1877F2),
                              onTap: () => _launchUrl(event.facebookUrl),
                            ),
                          if (event.instagramUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _socialButton(
                                icon: FontAwesomeIcons.instagram,
                                color: const Color(0xFFE4405F),
                                onTap: () {
                                  final url = event.instagramUrl.startsWith('http')
                                    ? event.instagramUrl
                                    : 'https://instagram.com/${event.instagramUrl.replaceAll('@', '')}';
                                  _launchUrl(url);
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Description Section
                    Text(
                      'About Event'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Committee Members Expansion
                    if (event.committeeMembers.isNotEmpty) ...[
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          // Force expansion tile colors
                          unselectedWidgetColor: isDark ? Colors.white70 : Colors.black54,
                          colorScheme: ColorScheme.fromSwatch().copyWith(
                            secondary: primaryColor,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          iconColor: primaryColor,
                          collapsedIconColor: isDark ? Colors.white70 : Colors.black54,
                          title: Text(
                            'Committee Contacts'.tr(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          children: event.committeeMembers.map((member) => _buildMemberTile(context, member)).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Location Map Preview
                    Text(
                      'Location'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(event.latitude, event.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId(event.id),
                            position: LatLng(event.latitude, event.longitude),
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        liteModeEnabled: true,
                      ),
                    ),

                    const SizedBox(height: 120), // Space for bottom action
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => _showTicketDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: primaryColor.withOpacity(0.4),
              ),
              child: Text(
                'Get Tickets'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, CommitteeMember member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(cfg.colorPrimary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            child: Icon(Icons.person, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  member.contactNumber,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (member.hasWhatsapp)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
              onPressed: () => _launchWhatsapp(member.contactNumber),
            ),
          IconButton(
            icon: Icon(Icons.phone_outlined, color: primaryColor),
            onPressed: () => _launchUrl('tel:${member.contactNumber}'),
          ),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FaIcon(icon, color: color, size: 20),
      ),
    );
  }

  void _showTicketDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(cfg.colorPrimary);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ticket Information'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (event.ticketTypes.isNotEmpty) ...[
                      Text(
                        'Available Tickets'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...event.ticketTypes.map((ticket) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ticket.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (ticket.description.isNotEmpty)
                                    Text(
                                      ticket.description,
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${ticket.currency} ${ticket.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],
                    if (event.ticketInstructions.isNotEmpty) ...[
                      Text(
                        'How to Purchase'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.ticketInstructions,
                        style: TextStyle(height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (event.ticketUrl.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _launchUrl(event.ticketUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Buy Tickets Online'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareEvent() async {
    await push(
      context,
      PromoteEventScreen(event: event),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsapp(String phone) async {
    final url = "https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editEvent(BuildContext context) async {
    final bool? edited = await push(
      context,
      CreateEventScreen(
        currentUser: context.read<AuthenticationBloc>().user!,
        eventToEdit: event,
      ),
    );
    if (edited == true && mounted) {
      context.read<HomeBloc>().add(GetListingsEvent());
      // Refresh current screen data
      final doc = await FirebaseFirestore.instance.collection('events').doc(event.id).get();
      if (doc.exists) {
        setState(() {
          event = EventModel.fromJson(doc.data()!);
          event.id = doc.id;
        });
      }
    }
  }

  Future<void> _deleteEvent(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event?'.tr()),
        content: Text('Are you sure you want to remove this event?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Yes'.tr(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<LoadingCubit>().showLoading(context, 'Deleting...'.tr(), false, Color(cfg.colorPrimary));
      context.read<HomeBloc>().add(EventDeleteEvent(event: event));
      context.read<LoadingCubit>().hideLoading();
      Navigator.pop(context);
    }
  }

  Future<void> _reportEvent(BuildContext context) async {
    final reasonController = TextEditingController();
    final isDark = isDarkMode(context);
    final reportSubmitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        title: Text('Report Event'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for reporting this event as inappropriate.'.tr(),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                hintText: 'Reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr())),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                showSnackBar(context, 'Please provide a reason.'.tr());
                return;
              }
              context.read<LoadingCubit>().showLoading(context, 'Submitting...'.tr(), false, Color(cfg.colorPrimary));
              try {
                await FirebaseFirestore.instance.collection('reports').add({
                  'eventId': event.id,
                  'eventTitle': event.title,
                  'eventAuthorId': event.createdBy,
                  'reporterId': context.read<AuthenticationBloc>().user?.userID,
                  'reporterName': context.read<AuthenticationBloc>().user?.fullName(),
                  'reason': reasonController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });
                context.read<LoadingCubit>().hideLoading();
                Navigator.pop(context, true);
              } catch (e) {
                context.read<LoadingCubit>().hideLoading();
                Navigator.pop(context, false);
                showSnackBar(context, 'Failed to submit report.'.tr());
              }
            },
            child: Text('Submit'.tr()),
          ),
        ],
      ),
    );

    if (reportSubmitted == true) {
      showSnackBar(context, 'Event reported. Thank you.'.tr());
    }
  }

  Future<void> _toggleFavoriteEvent(BuildContext context) async {
    final authBloc = context.read<AuthenticationBloc>();
    final currentUser = authBloc.user;
    if (currentUser == null) return;

    final isFav = currentUser.likedEventsIDs.contains(event.id);
    if (isFav) {
      currentUser.likedEventsIDs.remove(event.id);
      event.isFav = false;
    } else {
      if (!currentUser.likedEventsIDs.contains(event.id)) {
        currentUser.likedEventsIDs.add(event.id);
      }
      event.isFav = true;
    }

    await profileApiManager.updateCurrentUser(currentUser);
    authBloc.user = currentUser;
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildDetailedInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(cfg.colorPrimary);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
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
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
