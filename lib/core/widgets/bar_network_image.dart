import 'dart:io';

import 'package:flutter/material.dart';

import 'bar_resize_image.dart';
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

    final provider = _imageProvider(source);
    if (provider == null) {
      return errorWidget;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final width = _decodeDimension(constraints.maxWidth, pixelRatio);
        final height = _decodeDimension(constraints.maxHeight, pixelRatio);
        return Image(
          image: width == null && height == null
              ? provider
              : BarResizeImage(provider, width: width, height: height),
          fit: BoxFit.cover,
          loadingBuilder: !_isNetworkUrl(source)
              ? null
              : (context, child, loadingProgress) {
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
      },
    );
  }

  ImageProvider<Object>? _imageProvider(String source) {
    if (_isNetworkUrl(source)) {
      return NetworkImage(source);
    }
    if (source.startsWith('assets/')) {
      return AssetImage(source);
    }

    final localPath = source.startsWith('file://')
        ? Uri.parse(source).toFilePath()
        : source;
    final file = File(localPath);
    return file.existsSync() ? FileImage(file) : null;
  }

  int? _decodeDimension(double logicalSize, double pixelRatio) {
    return logicalSize.isFinite
        ? (logicalSize * pixelRatio).ceil().clamp(1, 0x7fffffff)
        : null;
  }

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
