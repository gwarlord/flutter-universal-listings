import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Video file extensions
  static const List<String> videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'];

  Future<String> uploadAdMedia(File file, String listerId, String adId) async {
    final ext = file.path.split('.').last.toLowerCase();
    
    // Compress video if it's a video file
    File fileToUpload = file;
    if (videoExtensions.contains(ext)) {
      try {
        fileToUpload = await _compressVideo(file);
      } catch (e) {
        print('Video compression failed, uploading original: $e');
        fileToUpload = file;
      }
    }

    final ref = _storage.ref().child('deal_ads/$listerId/$adId.$ext');
    final uploadTask = await ref.putFile(fileToUpload);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadAdThumbnail(File file, String listerId, String adId) async {
    final ref = _storage.ref().child('deal_ads/$listerId/${adId}_thumb.jpg');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Compresses video to reduce file size while maintaining quality
  /// Returns compressed video file or original if compression fails
  Future<File> _compressVideo(File file) async {
    try {
      final MediaInfo? info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.DefaultQuality,
        deleteOrigin: false, // Keep original file
        includeAudio: true,
        frameRate: 24,
      );
      
      if (info != null && info.path != null) {
        return File(info.path!);
      }
      return file;
    } catch (e) {
      print('Error compressing video: $e');
      return file;
    }
  }
}
