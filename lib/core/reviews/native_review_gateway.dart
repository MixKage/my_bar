import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// The system review prompt has no result indicating whether it was shown or
/// whether the user submitted a rating.
abstract interface class ReviewGateway {
  bool get isSupported;

  Future<bool> isAvailable();

  Future<void> requestReview();
}

/// Requests only the platform's native review dialog. An unavailable dialog
/// never redirects the user to a store listing or opens another application.
class NativeReviewGateway implements ReviewGateway {
  NativeReviewGateway({TargetPlatform? platform, bool isWeb = kIsWeb})
    : _platform = platform,
      _isWeb = isWeb;

  final TargetPlatform? _platform;
  final bool _isWeb;

  @override
  bool get isSupported {
    if (_isWeb) return false;
    final platform = _platform ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  @override
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    return InAppReview.instance.isAvailable();
  }

  @override
  Future<void> requestReview() async {
    if (!isSupported) return;
    await InAppReview.instance.requestReview();
  }
}
