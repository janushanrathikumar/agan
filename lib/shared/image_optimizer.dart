// lib/shared/image_optimizer.dart
//
// Shrinks and re-encodes a picture before it is stored in Firebase Storage.
//
// Pure Dart - it depends on nothing but package:image - so the admin upload
// pages and any maintenance script share exactly one implementation.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Where a picture is shown decides how large it needs to be.
enum ImageUse {
  /// Dish and drink photos: menu grid, item sheet and home carousel. The
  /// largest of those is a few hundred logical pixels wide, so 800 covers a
  /// high-density phone screen.
  menuPhoto(maxSide: 800),

  /// Category rail icons, drawn at roughly 48 logical pixels.
  categoryIcon(maxSide: 256);

  const ImageUse({required this.maxSide});

  final int maxSide;
}

class OptimizedImage {
  const OptimizedImage({
    required this.bytes,
    required this.contentType,
    required this.extension,
    required this.width,
    required this.height,
    required this.reencoded,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
  final int width;
  final int height;

  /// False when the original bytes were already the best option and are
  /// returned untouched.
  final bool reencoded;
}

class ImageOptimizer {
  ImageOptimizer._();

  static const jpegQuality = 80;

  /// Returns null when [input] is not a picture that can be decoded.
  ///
  /// Photos become JPEG. Pictures that really use transparency - bottle and
  /// can cut-outs - become PNG, because JPEG would paint their background
  /// black. Either way the longest side is capped for [use].
  static OptimizedImage? optimize(Uint8List input, ImageUse use) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return null;

    // Phone cameras store rotation as EXIF; browsers showing the JPEG we write
    // would otherwise ignore it and show the photo sideways.
    var image = img.bakeOrientation(decoded);

    final longest = math.max(image.width, image.height);
    if (longest > use.maxSide) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: use.maxSide,
              interpolation: img.Interpolation.cubic,
            )
          : img.copyResize(
              image,
              height: use.maxSide,
              interpolation: img.Interpolation.cubic,
            );
    }

    final transparent = _usesTransparency(image);
    final bytes = transparent
        ? img.encodePng(image, level: 9)
        : img.encodeJpg(image, quality: jpegQuality);

    // Never hand back something heavier than what came in: an original that is
    // already small enough, in a format every browser shows, and lighter than
    // our re-encode is kept exactly as it is.
    final original = _webSafeFormat(input);
    if (original != null &&
        longest <= use.maxSide &&
        input.length <= bytes.length) {
      return OptimizedImage(
        bytes: input,
        contentType: original.contentType,
        extension: original.extension,
        width: decoded.width,
        height: decoded.height,
        reencoded: false,
      );
    }

    return OptimizedImage(
      bytes: bytes,
      contentType: transparent ? 'image/png' : 'image/jpeg',
      extension: transparent ? 'png' : 'jpg',
      width: image.width,
      height: image.height,
      reencoded: true,
    );
  }

  /// An alpha channel alone proves nothing - most exported PNGs carry one
  /// that is fully opaque - so look for a pixel that is actually see-through.
  static bool _usesTransparency(img.Image image) {
    if (!image.hasAlpha) return false;
    for (final pixel in image) {
      if (pixel.a < pixel.maxChannelValue) return true;
    }
    return false;
  }

  static ({String contentType, String extension})? _webSafeFormat(
    Uint8List bytes,
  ) {
    switch (img.findFormatForData(bytes)) {
      case img.ImageFormat.jpg:
        return (contentType: 'image/jpeg', extension: 'jpg');
      case img.ImageFormat.png:
        return (contentType: 'image/png', extension: 'png');
      case img.ImageFormat.webp:
        return (contentType: 'image/webp', extension: 'webp');
      default:
        return null;
    }
  }
}
