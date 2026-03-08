import 'package:flutter/widgets.dart';

const double kTabletShortestSideBreakpoint = 600;
const double kTabletLandscapeSideNavWidthBreakpoint = 980;

bool isTabletLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide >= kTabletShortestSideBreakpoint;
}

bool useLandscapeSideNavigation(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return isTabletLayout(context) &&
      size.width >= kTabletLandscapeSideNavWidthBreakpoint &&
      size.width > size.height;
}

double resolveAdaptiveHorizontalPadding(
  BuildContext context, {
  double maxContentWidth = 980,
  double minPadding = 16,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final centeredPadding = (width - maxContentWidth) / 2;
  if (centeredPadding <= minPadding) {
    return minPadding;
  }
  return centeredPadding;
}
