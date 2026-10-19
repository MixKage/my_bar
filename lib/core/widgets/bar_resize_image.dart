import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes only the pixels needed to paint an image at its displayed size.
///
/// Unlike an exact two-axis [ResizeImage], this keeps the source aspect ratio.
/// Cover images need enough pixels for the cropped area, while contain images
/// only need enough for the area they actually occupy. Dimensions are physical
/// pixels; a null dimension means the layout is unbounded on that axis.
class BarResizeImage extends ImageProvider<BarResizeImageKey> {
  const BarResizeImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : assert(width != null || height != null),
       assert(width == null || width > 0),
       assert(height == null || height > 0),
       assert(fit == BoxFit.cover || fit == BoxFit.contain);

  final ImageProvider<Object> imageProvider;
  final int? width;
  final int? height;
  final BoxFit fit;

  @override
  Future<BarResizeImageKey> obtainKey(ImageConfiguration configuration) {
    return imageProvider
        .obtainKey(configuration)
        .then((key) => BarResizeImageKey(key, width, height, fit));
  }

  @override
  ImageStreamCompleter loadImage(
    BarResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    final completer = imageProvider.loadImage(key.providerKey, (
      buffer, {
      getTargetSize,
    }) {
      assert(getTargetSize == null);
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          final widthScale = width == null ? null : width! / intrinsicWidth;
          final heightScale = height == null ? null : height! / intrinsicHeight;
          final double scale;
          if (widthScale == null) {
            scale = heightScale!;
          } else if (heightScale == null) {
            scale = widthScale;
          } else {
            scale = fit == BoxFit.cover
                ? math.max(widthScale, heightScale)
                : math.min(widthScale, heightScale);
          }

          // Leave small sources at their native resolution. Setting just the
          // width lets the codec preserve the original aspect ratio exactly.
          return ui.TargetImageSize(
            width: (intrinsicWidth * scale.clamp(0.0, 1.0)).ceil().clamp(
              1,
              intrinsicWidth,
            ),
          );
        },
      );
    });
    completer.addEphemeralErrorListener((error, stack) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) {
    return other is BarResizeImage &&
        other.imageProvider == imageProvider &&
        other.width == width &&
        other.height == height &&
        other.fit == fit;
  }

  @override
  int get hashCode => Object.hash(imageProvider, width, height, fit);
}

@immutable
class BarResizeImageKey {
  const BarResizeImageKey(this.providerKey, this.width, this.height, this.fit);

  final Object providerKey;
  final int? width;
  final int? height;
  final BoxFit fit;

  @override
  bool operator ==(Object other) {
    return other is BarResizeImageKey &&
        other.providerKey == providerKey &&
        other.width == width &&
        other.height == height &&
        other.fit == fit;
  }

  @override
  int get hashCode => Object.hash(providerKey, width, height, fit);
}
