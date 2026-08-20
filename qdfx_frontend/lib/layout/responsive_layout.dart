import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;  // Make this optional (nullable)
  final Widget desktopBody;
  final bool useScaffold;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,  // Now optional
    required this.desktopBody,
    this.useScaffold = true,
  });

  // Breakpoints
  static const int mobileBreakpoint = 600;
  static const int tabletBreakpoint = 900;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    Widget child;

    if (width < mobileBreakpoint) {
      child = mobileBody;
    } else if (width < tabletBreakpoint) {
      // If tabletBody is not provided, fall back to mobileBody
      child = tabletBody ?? mobileBody;
    } else {
      child = desktopBody;
    }

    if (useScaffold) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: child,
      );
    }
    return child;
  }
}

// Helper extensions for responsive values
extension ResponsiveExtensions on num {
  double w(BuildContext context) => this * MediaQuery.of(context).size.width / 100;
  double h(BuildContext context) => this * MediaQuery.of(context).size.height / 100;
}

extension ResponsivePadding on Widget {
  Widget responsivePadding(BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final width = MediaQuery.of(context).size.width;
    double value = mobile;
    if (width >= 900) value = desktop;
    else if (width >= 600) value = tablet;
    return Padding(
      padding: EdgeInsets.all(value),
      child: this,
    );
  }
}