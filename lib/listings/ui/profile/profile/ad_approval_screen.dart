import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:provider/provider.dart';
import 'package:instaflutter/listings/services/deal_ad_admin_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:instaflutter/core/ui/video/adaptive_video_player.dart';
import 'package:instaflutter/listings/ui/profile/profile/_dialog_video_player.dart';
import 'package:video_player/video_player.dart';

class AdApprovalScreen extends StatefulWidget {
  final ListingsUser currentUser;
  const AdApprovalScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<AdApprovalScreen> createState() => _AdApprovalScreenState();
}

class _AdApprovalScreenState extends State<AdApprovalScreen> {
  late DealAdAdminService _dealAdAdminService;
  @override
  void initState() {
    super.initState();
    _dealAdAdminService = DealAdAdminService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ad Approval'.tr())),
      body: StreamBuilder<List<DealAdModel>>(
        stream: _dealAdAdminService.getPendingAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return Center(child: Text('No pending ads'.tr()));
          }
          return ListView.builder(
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: ad.mediaUrl.isNotEmpty
                      ? (ad.mediaType == 'image'
                          ? Image.network(ad.mediaUrl, width: 48, height: 48, fit: BoxFit.cover)
                          : GestureDetector(
                              onTap: () async {
                                VideoPlayerController? controller;
                                await showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (context) => Dialog(
                                    child: FutureBuilder<VideoPlayerController>(
                                      future: _initVideoController(ad.mediaUrl, autoPlay: true),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const SizedBox(
                                            width: 200,
                                            height: 200,
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }
                                        controller = snapshot.data!;
                                        return WillPopScope(
                                          onWillPop: () async {
                                            controller?.pause();
                                            controller?.dispose();
                                            return true;
                                          },
                                          child: StatefulBuilder(
                                            builder: (context, setState) {
                                              return SizedBox(
                                                width: 320,
                                                height: 360,
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        width: 300,
                                                        height: 300,
                                                        child: DialogVideoPlayer(controller: controller!),
                                                      ),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          IconButton(
                                                            icon: Icon(
                                                              controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                                            ),
                                                            onPressed: () {
                                                              setState(() {
                                                                controller!.value.isPlaying ? controller!.pause() : controller!.play();
                                                              });
                                                            },
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.close),
                                                            onPressed: () {
                                                              controller?.pause();
                                                              controller?.dispose();
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                                controller?.pause();
                                controller?.dispose();
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.black12,
                                    child: const Icon(Icons.videocam, size: 32, color: Colors.black54),
                                  ),
                                  const Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 20),
                                  ),
                                ],
                              ),
                            ))
                      : const Icon(Icons.image, size: 48),
                  title: Text(
                    ad.caption.isNotEmpty ? ad.caption : 'Untitled',
                    maxLines: null,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Duration: ${ad.durationDays} days'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          try {
                            await _dealAdAdminService.approveAd(ad.id!, widget.currentUser.userID);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ad approved'.tr())),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to approve ad: $e')), // Show error
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          try {
                            await _dealAdAdminService.rejectAd(ad.id!, widget.currentUser.userID);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ad rejected'.tr())),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to reject ad: $e')), // Show error
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<VideoPlayerController> _initVideoController(String url, {bool autoPlay = false}) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller.setLooping(true);
    if (autoPlay) controller.play();
    return controller;
  }
}
