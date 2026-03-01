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
    return Image.network(
      imageUrl,
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
}
