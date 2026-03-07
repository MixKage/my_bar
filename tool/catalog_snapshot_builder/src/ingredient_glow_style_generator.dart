import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:my_bar/features/bar/domain/models/ingredient.dart';

class IngredientGlowStyle {
  const IngredientGlowStyle({
    required this.glowColor,
    this.glowSecondaryColor,
    required this.glowOffsetX,
    required this.glowOffsetY,
    required this.glowScale,
    required this.glowOpacity,
  });

  final String glowColor;
  final String? glowSecondaryColor;
  final double glowOffsetX;
  final double glowOffsetY;
  final double glowScale;
  final double glowOpacity;
}

class IngredientGlowStyleGenerator {
  const IngredientGlowStyleGenerator({
    this.enableImageSampling = true,
    this.timeout = const Duration(seconds: 10),
    this.maxConcurrentRequests = 8,
  });

  final bool enableImageSampling;
  final Duration timeout;
  final int maxConcurrentRequests;

  Future<Map<String, IngredientGlowStyle>> generate(
    Iterable<Ingredient> ingredients,
  ) async {
    final source = ingredients.toList(growable: false);
    final byId = <String, IngredientGlowStyle>{};
    final paletteByImageUrlFuture = <String, Future<_Palette?>>{};

    for (var index = 0; index < source.length; index += maxConcurrentRequests) {
      final chunk = source.skip(index).take(maxConcurrentRequests);
      await Future.wait<void>(
        chunk.map((ingredient) async {
          if (ingredient.id.trim().isEmpty) {
            return;
          }
          final palette = await _resolvePalette(
            ingredient,
            paletteByImageUrlFuture,
          );
          byId[ingredient.id] = _styleFromPalette(
            ingredientId: ingredient.id,
            palette: palette,
          );
        }),
      );
    }

    return byId;
  }

  Future<_Palette?> _resolvePalette(
    Ingredient ingredient,
    Map<String, Future<_Palette?>> cache,
  ) async {
    if (!enableImageSampling) {
      return null;
    }
    final imageUrl = ingredient.image.trim();
    if (imageUrl.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    final future = cache.putIfAbsent(imageUrl, () => _sampleImagePalette(uri));
    return future;
  }

  Future<_Palette?> _sampleImagePalette(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = await _readResponseBytes(response).timeout(timeout);
      if (bytes.isEmpty) {
        return null;
      }

      final image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      final thumbnail = _downscale(image, maxSide: 72);
      final bucket = _extractDominantBucket(thumbnail);
      if (bucket == null) {
        return null;
      }
      final averageRgb = bucket.averageColor;
      final hsl = _rgbToHsl(
        averageRgb.red.toDouble(),
        averageRgb.green.toDouble(),
        averageRgb.blue.toDouble(),
      );
      final primaryHsl = _Hsl(
        hsl.hue,
        hsl.saturation.clamp(0.48, 0.84),
        hsl.lightness.clamp(0.44, 0.66),
      );
      final secondaryHsl = _Hsl(
        (primaryHsl.hue + 22) % 360,
        (primaryHsl.saturation * 0.82).clamp(0.36, 0.76),
        (primaryHsl.lightness + 0.1).clamp(0.46, 0.74),
      );

      return _Palette(
        primary: _hslToRgb(primaryHsl),
        secondary: _hslToRgb(secondaryHsl),
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  IngredientGlowStyle _styleFromPalette({
    required String ingredientId,
    required _Palette? palette,
  }) {
    final hash = _fnv1a32(ingredientId);
    final fallbackHue = (hash % 360).toDouble();
    final fallbackPrimary = _hslToRgb(_Hsl(fallbackHue, 0.64, 0.56));
    final fallbackSecondary = _hslToRgb(
      _Hsl((fallbackHue + 24) % 360, 0.52, 0.62),
    );

    final resolvedPrimary = palette?.primary ?? fallbackPrimary;
    final resolvedSecondary = palette?.secondary ?? fallbackSecondary;

    final offsetX = _round3(_mapByte(hash & 0xFF, -0.34, 0.34));
    final offsetY = _round3(_mapByte((hash >> 8) & 0xFF, -0.24, 0.24));
    final scale = _round3(_mapByte((hash >> 16) & 0xFF, 0.88, 1.28));
    final opacity = _round3(_mapByte((hash >> 24) & 0xFF, 0.24, 0.44));

    return IngredientGlowStyle(
      glowColor: _toHex(resolvedPrimary),
      glowSecondaryColor: _toHex(resolvedSecondary),
      glowOffsetX: offsetX,
      glowOffsetY: offsetY,
      glowScale: scale,
      glowOpacity: opacity,
    );
  }
}

Future<Uint8List> _readResponseBytes(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

img.Image _downscale(img.Image image, {required int maxSide}) {
  final width = image.width;
  final height = image.height;
  final longest = math.max(width, height);
  if (longest <= maxSide) {
    return image;
  }
  final factor = maxSide / longest;
  final nextWidth = math.max(1, (width * factor).round());
  final nextHeight = math.max(1, (height * factor).round());
  return img.copyResize(
    image,
    width: nextWidth,
    height: nextHeight,
    interpolation: img.Interpolation.linear,
  );
}

_ColorBucket? _extractDominantBucket(img.Image image) {
  final buckets = <int, _ColorBucket>{};

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final alpha = _channel(pixel.a);
      if (alpha < 150) {
        continue;
      }
      final red = _channel(pixel.r);
      final green = _channel(pixel.g);
      final blue = _channel(pixel.b);
      final hsl = _rgbToHsl(red.toDouble(), green.toDouble(), blue.toDouble());
      if (hsl.saturation < 0.12) {
        continue;
      }
      if (hsl.lightness < 0.08 || hsl.lightness > 0.94) {
        continue;
      }

      final hueBucket = (hsl.hue / 10).round().clamp(0, 36);
      final satBucket = (hsl.saturation * 8).round().clamp(0, 8);
      final lightBucket = (hsl.lightness * 8).round().clamp(0, 8);
      final key = hueBucket | (satBucket << 8) | (lightBucket << 16);

      final bucket = buckets.putIfAbsent(key, () => _ColorBucket());
      bucket.add(red, green, blue, hsl.saturation);
    }
  }

  if (buckets.isEmpty) {
    return null;
  }

  _ColorBucket? best;
  for (final candidate in buckets.values) {
    if (best == null || candidate.score > best.score) {
      best = candidate;
    }
  }
  return best;
}

double _mapByte(int value, double min, double max) {
  final clamped = value.clamp(0, 255);
  return min + (max - min) * (clamped / 255.0);
}

int _fnv1a32(String source) {
  var hash = 0x811C9DC5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

int _channel(num value) {
  final rounded = value.round();
  if (rounded < 0) {
    return 0;
  }
  if (rounded > 255) {
    return 255;
  }
  return rounded;
}

double _round3(double value) => (value * 1000).roundToDouble() / 1000;

String _toHex(_Rgb color) {
  final red = color.red.toRadixString(16).padLeft(2, '0').toUpperCase();
  final green = color.green.toRadixString(16).padLeft(2, '0').toUpperCase();
  final blue = color.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#$red$green$blue';
}

_Hsl _rgbToHsl(double red, double green, double blue) {
  final r = red / 255.0;
  final g = green / 255.0;
  final b = blue / 255.0;

  final maxValue = math.max(r, math.max(g, b));
  final minValue = math.min(r, math.min(g, b));
  final delta = maxValue - minValue;

  var hue = 0.0;
  if (delta != 0) {
    if (maxValue == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxValue == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
  }
  if (hue < 0) {
    hue += 360;
  }

  final lightness = (maxValue + minValue) / 2;
  final saturation = delta == 0 ? 0.0 : delta / (1 - (2 * lightness - 1).abs());
  return _Hsl(hue, saturation, lightness);
}

_Rgb _hslToRgb(_Hsl hsl) {
  final hue = hsl.hue;
  final saturation = hsl.saturation.clamp(0, 1).toDouble();
  final lightness = hsl.lightness.clamp(0, 1).toDouble();

  final chroma = (1 - (2 * lightness - 1).abs()) * saturation;
  final x = chroma * (1 - ((hue / 60) % 2 - 1).abs());
  final m = lightness - chroma / 2;

  double r1 = 0;
  double g1 = 0;
  double b1 = 0;

  if (hue < 60) {
    r1 = chroma;
    g1 = x;
  } else if (hue < 120) {
    r1 = x;
    g1 = chroma;
  } else if (hue < 180) {
    g1 = chroma;
    b1 = x;
  } else if (hue < 240) {
    g1 = x;
    b1 = chroma;
  } else if (hue < 300) {
    r1 = x;
    b1 = chroma;
  } else {
    r1 = chroma;
    b1 = x;
  }

  final red = ((r1 + m) * 255).round().clamp(0, 255).toInt();
  final green = ((g1 + m) * 255).round().clamp(0, 255).toInt();
  final blue = ((b1 + m) * 255).round().clamp(0, 255).toInt();
  return _Rgb(red, green, blue);
}

class _Palette {
  const _Palette({required this.primary, required this.secondary});

  final _Rgb primary;
  final _Rgb secondary;
}

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;
}

class _Hsl {
  const _Hsl(this.hue, this.saturation, this.lightness);

  final double hue;
  final double saturation;
  final double lightness;
}

class _ColorBucket {
  var _count = 0;
  var _sumRed = 0;
  var _sumGreen = 0;
  var _sumBlue = 0;
  var _sumSaturation = 0.0;

  void add(int red, int green, int blue, double saturation) {
    _count++;
    _sumRed += red;
    _sumGreen += green;
    _sumBlue += blue;
    _sumSaturation += saturation;
  }

  _Rgb get averageColor {
    if (_count == 0) {
      return const _Rgb(125, 75, 255);
    }
    return _Rgb(
      (_sumRed / _count).round().clamp(0, 255),
      (_sumGreen / _count).round().clamp(0, 255),
      (_sumBlue / _count).round().clamp(0, 255),
    );
  }

  double get score {
    if (_count == 0) {
      return 0;
    }
    final averageSaturation = _sumSaturation / _count;
    return _count * (0.75 + averageSaturation);
  }
}
