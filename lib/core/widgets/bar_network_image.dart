import 'dart:io';

import 'package:flutter/material.dart';

import 'stretched_dots_loader.dart';

class BarNetworkImage extends StatelessWidget {
  const BarNetworkImage({
    required this.imageUrl,
    required this.loadingColor,
    required this.loadingBackgroundColor,
    required this.errorWidget,
    super.key,
  });

  final String imageUrl;
  final Color loadingColor;
  final Color loadingBackgroundColor;
  final Widget errorWidget;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl.trim();
    if (source.isEmpty) {
      return errorWidget;
    }

    if (_isNetworkUrl(source)) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return StretchedDotsLoader(
            size: 36,
            color: loadingColor,
            backgroundColor: loadingBackgroundColor,
          );
        },
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }

    final localPath = source.startsWith('file://')
        ? Uri.parse(source).toFilePath()
        : source;
    final file = File(localPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }

    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }

    return errorWidget;
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
