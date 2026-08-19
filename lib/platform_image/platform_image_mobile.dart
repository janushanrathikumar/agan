import 'package:flutter/material.dart';

Widget buildUniversalImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  if (imageUrl.isEmpty) return fallback;

  return Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => fallback,
  );
}