import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/listings/model/proof_of_payment_model.dart';
import 'package:caribtap/listings/services/proof_of_payment_service.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class ProofOfPaymentUploadWidget extends StatefulWidget {
  final String listingId;
  final String orderId;
  final String currentUserId;
  final bool isLister; //true if viewer is lister/staff, false if customer
  final ProofOfPayment? proofOfPayment;
  final bool listingAcceptsProofOfPayment; // Check if listing has POP enabled
  final VoidCallback? onUploadComplete;
  final VoidCallback? onReviewComplete;

  const ProofOfPaymentUploadWidget({
    Key? key,
    required this.listingId,
    required this.orderId,
    required this.currentUserId,
    this.isLister = false,
    this.proofOfPayment,
    this.listingAcceptsProofOfPayment = false,
    this.onUploadComplete,
    this.onReviewComplete,
  }) : super(key: key);

  @override
  State<ProofOfPaymentUploadWidget> createState() =>
      _ProofOfPaymentUploadWidgetState();
}

class _ProofOfPaymentUploadWidgetState
    extends State<ProofOfPaymentUploadWidget> {
  late ProofOfPaymentService _popService;
  bool _isUploading = false;
  bool _isExpanded = false;
  String? _uploadError;
  late TextEditingController _reviewControllerNote;
  ProofOfPayment? _resolvedProofOfPayment;
  bool _isLoadingProof = false;

  @override
  void initState() {
    super.initState();
    _popService = ProofOfPaymentService();
    _reviewControllerNote = TextEditingController();
    _resolvedProofOfPayment = widget.proofOfPayment;
    _tryLoadLatestProof();
  }

  @override
  void didUpdateWidget(covariant ProofOfPaymentUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.proofOfPayment != oldWidget.proofOfPayment) {
      _resolvedProofOfPayment = widget.proofOfPayment;
    }
    if (widget.orderId != oldWidget.orderId ||
        widget.listingId != oldWidget.listingId ||
        widget.proofOfPayment != oldWidget.proofOfPayment) {
      _tryLoadLatestProof();
    }
  }

  @override
  void dispose() {
    _reviewControllerNote.dispose();
    super.dispose();
  }

  Future<void> _tryLoadLatestProof() async {
    if (!mounted || _isLoadingProof) return;

    final provided = _resolvedProofOfPayment ?? widget.proofOfPayment;
    final shouldFetch = provided == null || !provided.hasUploads;
    if (!shouldFetch) return;

    setState(() {
      _isLoadingProof = true;
    });

    try {
      final latest = await _popService.getProofOfPayment(
        listingId: widget.listingId,
        orderId: widget.orderId,
      );
      if (!mounted) return;
      if (latest != null) {
        setState(() {
          _resolvedProofOfPayment = latest;
        });
      }
    } catch (_) {
      // Non-fatal: keep rendering provided data if canonical fetch fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProof = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      final file = File(image.path);
      final upload = await _popService.uploadProofOfPayment(
        file: file,
        orderId: widget.orderId,
        uploadedByUid: widget.currentUserId,
        fileType: 'IMAGE',
        fileName: image.name,
      );

      // Submit to Firestore
      await _popService.submitProofOfPayment(
        listingId: widget.listingId,
        orderId: widget.orderId,
        upload: upload,
        customerUid: widget.currentUserId,
      );

      setState(() {
        _isUploading = false;
      });

      showSnackBar(context, 'Proof of payment uploaded successfully'.tr());
      widget.onUploadComplete?.call();
      await _tryLoadLatestProof();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed: ${e.toString()}'.tr();
      });
      showSnackBar(context, _uploadError ?? 'Upload failed'.tr());
    }
  }

  Future<void> _pickAndUploadPDF() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);

      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      final upload = await _popService.uploadProofOfPayment(
        file: file,
        orderId: widget.orderId,
        uploadedByUid: widget.currentUserId,
        fileType: 'PDF',
        fileName: result.files.first.name,
      );

      // Submit to Firestore
      await _popService.submitProofOfPayment(
        listingId: widget.listingId,
        orderId: widget.orderId,
        upload: upload,
        customerUid: widget.currentUserId,
      );

      setState(() {
        _isUploading = false;
      });

      showSnackBar(context, 'Proof of payment uploaded successfully'.tr());
      widget.onUploadComplete?.call();
      await _tryLoadLatestProof();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed: ${e.toString()}'.tr();
      });
      showSnackBar(context, _uploadError ?? 'Upload failed'.tr());
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo == null) return;

      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      final file = File(photo.path);
      final upload = await _popService.uploadProofOfPayment(
        file: file,
        orderId: widget.orderId,
        uploadedByUid: widget.currentUserId,
        fileType: 'IMAGE',
        fileName: photo.name,
      );

      // Submit to Firestore
      await _popService.submitProofOfPayment(
        listingId: widget.listingId,
        orderId: widget.orderId,
        upload: upload,
        customerUid: widget.currentUserId,
      );

      setState(() {
        _isUploading = false;
      });

      showSnackBar(context, 'Proof of payment uploaded successfully'.tr());
      widget.onUploadComplete?.call();
      await _tryLoadLatestProof();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed: ${e.toString()}'.tr();
      });
      showSnackBar(context, _uploadError ?? 'Upload failed'.tr());
    }
  }

  void _viewFile(String fileUrl) async {
    try {
      if (await canLaunch(fileUrl)) {
        await launch(fileUrl);
      } else {
        showSnackBar(context, 'Cannot open file'.tr());
      }
    } catch (e) {
      showSnackBar(context, 'Error opening file: ${e.toString()}'.tr());
    }
  }

  void _showReviewDialog(ProofOfPaymentUpload upload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review Proof of Payment'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: ${upload.fileName}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploaded: ${DateFormat('MMM dd, yyyy hh:mm').format(upload.uploadedAt.toDate())}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text('Decision:'.tr()),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewControllerNote,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Optional note...'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reviewProof(upload, 'REJECTED');
            },
            child: Text('Reject'.tr(), style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reviewProof(upload, 'VERIFIED');
            },
            child:
                Text('Verify'.tr(), style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewProof(ProofOfPaymentUpload upload, String decision) async {
    try {
      await _popService.reviewProofOfPayment(
        listingId: widget.listingId,
        orderId: widget.orderId,
        decision: decision,
        editorUid: widget.currentUserId,
        reviewNote: _reviewControllerNote.text.trim(),
      );

      _reviewControllerNote.clear();
      showSnackBar(context,
          'Proof of payment $decision successfully'.tr());
      widget.onReviewComplete?.call();
      await _tryLoadLatestProof();
    } catch (e) {
      showSnackBar(context, 'Review failed: ${e.toString()}'.tr());
    }
  }

  bool _shouldShow() {
    // Only show if listing has POP enabled
    return widget.listingAcceptsProofOfPayment;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow()) {
      return const SizedBox.shrink();
    }

    final isDark = isDarkMode(context);
    // Initialize default POP if null
    final pop = _resolvedProofOfPayment ?? 
        ProofOfPayment(
          enabledAtOrderTime: false,
          uploads: [],
          overallStatus: 'NONE',
        );
    final latestUpload = pop.getLatestUpload();

    return Column(
      children: [
        // Collapsible Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: ListTile(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            leading: Icon(Icons.receipt_long, color: Color(0xFF2196F3)),
            title: Text(
              'Proof of Payment'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            trailing: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.expand_more,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
        // Collapsible Content
        if (_isExpanded)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isLister) ...[
                    // CUSTOMER VIEW
                    if (!pop.hasUploads) ...[
                      Text('No proof of payment uploaded yet.'.tr()),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: Text('Take Photo'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickAndUploadImage,
                              icon: const Icon(Icons.image),
                              label: Text('Choose Image'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUploadPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text('Choose PDF'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(pop.overallStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(pop.overallStatus),
                              color: _getStatusColor(pop.overallStatus),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pop.overallStatus.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(pop.overallStatus),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (latestUpload != null) ...[
                        Text(
                          'Latest Upload: ${DateFormat('MMM dd, yyyy').format(latestUpload.uploadedAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewFile(latestUpload.fileUrl),
                                icon: const Icon(Icons.visibility),
                                label: Text('View'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _pickAndUploadImage,
                                icon: const Icon(Icons.autorenew),
                                label: Text('Replace'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ] else ...[
                    // LISTER (STAFF) VIEW
                    if (_isLoadingProof)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (!pop.hasUploads) ...[
                      Text('No proof of payment submitted yet.'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          )),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(pop.overallStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(pop.overallStatus),
                              color: _getStatusColor(pop.overallStatus),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pop.overallStatus.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(pop.overallStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (latestUpload != null) ...[
                        Text(
                          'Uploaded: ${DateFormat('MMM dd, yyyy hh:mm').format(latestUpload.uploadedAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        if (latestUpload.reviewedAt != null)
                          Text(
                            'Reviewed: ${DateFormat('MMM dd, yyyy hh:mm').format(latestUpload.reviewedAt!.toDate())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        if (latestUpload.reviewerNote != null &&
                            latestUpload.reviewerNote!.isNotEmpty)
                          Text(
                            'Note: ${latestUpload.reviewerNote}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewFile(latestUpload.fileUrl),
                                icon: const Icon(Icons.visibility),
                                label: Text('View'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showReviewDialog(latestUpload),
                                icon: const Icon(Icons.done_all),
                                label: Text('Review'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                  if (_uploadError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _uploadError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                  if (_isUploading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'SUBMITTED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'SUBMITTED':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }
}
