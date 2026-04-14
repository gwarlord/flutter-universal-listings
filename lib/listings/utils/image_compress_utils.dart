import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Compresses an image [File] so neither dimension exceeds [maxDimension]
/// pixels, at JPEG quality [quality] (ignored for PNG files).
///
/// - Skips on web (returns original).
/// - Returns the original file if compression fails or produces a larger file.
/// - Output is written to the system temp directory and does NOT overwrite the
///   source file.
Future<File> compressImageFile(
  File file, {
  int maxDimension = 1600,
  int quality = 82,
}) async {
  if (kIsWeb) return file;

  try {
    final ext = p.extension(file.path).toLowerCase();
    final isPng = ext == '.png';

    // Build a unique temp path so concurrent compressions don't collide.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final targetPath = p.join(
      Directory.systemTemp.path,
      '${p.basenameWithoutExtension(file.path)}_c$stamp.${isPng ? 'png' : 'jpg'}',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: isPng ? CompressFormat.png : CompressFormat.jpeg,
      autoCorrectionAngle: true,
    );

    if (result == null) return file;

    final compressed = File(result.path);

    // Don't use compressed output if it somehow ended up larger.
    if (await compressed.length() >= await file.length()) return file;

    return compressed;
  } catch (e) {
    debugPrint('compressImageFile() error: $e');
    return file;
  }
}
