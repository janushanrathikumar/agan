// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// View types already registered, keyed by URL and fit.
///
/// Registering a fresh factory on every build (the old code stamped the view
/// type with the current time) made each rebuild - typing in the menu search,
/// switching category - throw away every `<img>` and create a new one, so the
/// browser fetched and decoded every picture again. One factory per picture is
/// enough: it is invoked once for each place that picture is shown.
final Set<String> _registered = <String>{};

String _objectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.cover:
    case BoxFit.fitWidth:
    case BoxFit.fitHeight:
      return 'cover';
  }
}

Widget buildUniversalImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  if (imageUrl.isEmpty) return fallback;

  final objectFit = _objectFit(fit);
  // The URL itself is the key: a hash could let two pictures share a view.
  final viewType = 'img-$objectFit-$imageUrl';

  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return html.ImageElement()
        ..src = imageUrl
        // Pictures below the fold are fetched only when scrolled to, and
        // decoding stays off the main thread.
        ..setAttribute('loading', 'lazy')
        ..setAttribute('decoding', 'async')
        ..draggable = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.border = 'none';
    });
  }

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
