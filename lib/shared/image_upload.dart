// lib/shared/image_upload.dart
//
// The one way the app puts a picture into Firebase Storage: shrink it with
// [ImageOptimizer], then upload it with headers that let browsers keep it.

import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'image_optimizer.dart';

export 'image_optimizer.dart' show ImageUse;

class UploadedImage {
  const UploadedImage({required this.url, required this.fileName});

  final String url;

  /// The object name inside its folder, stored next to the URL so the file
  /// can be deleted when it is replaced.
  final String fileName;
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageUploader {
  ImageUploader._();

  /// Every upload gets a new timestamped name, so the bytes behind a name
  /// never change - which is what makes it safe to let browsers and phones
  /// reuse a downloaded picture for a year instead of fetching it again on
  /// every visit. Without this Firebase serves `private, max-age=0`.
  static const cacheControl = 'public, max-age=31536000, immutable';

  static Future<UploadedImage> upload(
    Uint8List picked, {
    required String folder,
    required String nameHint,
    required ImageUse use,
  }) async {
    final optimized = ImageOptimizer.optimize(picked, use);
    if (optimized == null) {
      throw const ImageUploadException(
        'This file could not be read as a picture. Please choose a JPG, PNG '
        'or WebP image.',
      );
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_safeBase(nameHint)}'
        '.${optimized.extension}';
    final ref = FirebaseStorage.instance.ref('$folder/$fileName');

    await ref.putData(
      optimized.bytes,
      SettableMetadata(
        contentType: optimized.contentType,
        cacheControl: cacheControl,
      ),
    );

    return UploadedImage(url: await ref.getDownloadURL(), fileName: fileName);
  }

  /// Removes a picture that is no longer referenced. A missing file is not an
  /// error - it only means there is nothing left to clean up.
  static Future<void> deleteQuietly(String folder, String? fileName) async {
    if (fileName == null || fileName.trim().isEmpty) return;
    try {
      await FirebaseStorage.instance.ref('$folder/$fileName').delete();
    } catch (error) {
      debugPrint('Could not delete $folder/$fileName: $error');
    }
  }

  /// A readable, URL-safe name without the original extension - the stored
  /// file's extension follows the format it was re-encoded to.
  static String _safeBase(String hint) {
    final dot = hint.lastIndexOf('.');
    final stem = dot > 0 ? hint.substring(0, dot) : hint;
    final safe = stem.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final trimmed = safe.length > 60 ? safe.substring(0, 60) : safe;
    return trimmed.isEmpty ? 'image' : trimmed;
  }
}
