import 'package:flutter/material.dart';

/// Custom page transition animations for smooth, modern navigation
class PageTransitions {
  /// Smooth fade transition (best for modal-like navigation)
  static PageRouteBuilder fadeTransition(
    Widget Function(BuildContext) builder,
  ) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      opaque: false, // Optimize by rendering both screens during transition
    );
  }

  /// Slide-in from right transition (best for hierarchical navigation)
  static PageRouteBuilder slideInRightTransition(
    Widget Function(BuildContext) builder,
  ) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      opaque: true, // Opaque slide transition
    );
  }

  /// Slide-in from bottom transition (best for sheet-like navigation)
  static PageRouteBuilder slideInUpTransition(
    Widget Function(BuildContext) builder,
  ) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      opaque: false,
    );
  }

  /// Combined fade + slide transition (smooth & modern)
  static PageRouteBuilder fadeSlideTransition(
    Widget Function(BuildContext) builder,
  ) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        var fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      opaque: false,
    );
  }

  /// Scale + fade transition (engaging entrance)
  static PageRouteBuilder scaleTransition(
    Widget Function(BuildContext) builder,
  ) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        var scaleTween = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        var fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      opaque: false,
    );
  }
}

/// Extension for easy navigation with transitions
extension NavigationWithTransition on BuildContext {
  /// Navigate to a named route with a smooth transition
  Future<T?> pushWithTransition<T>(
    String routeName, {
    Object? arguments,
    TransitionType transition = TransitionType.slideInRight,
  }) {
    return Navigator.of(this).push<T?>(
      _buildTransition<T>(
        routeName,
        arguments: arguments,
        transition: transition,
      ),
    );
  }

  /// Replace current route with a new route and transition
  Future<T?> pushReplacementWithTransition<T>(
    String routeName, {
    Object? arguments,
    TransitionType transition = TransitionType.slideInRight,
  }) {
    return Navigator.of(this).pushReplacement<T?, void>(
      _buildTransition<T>(
        routeName,
        arguments: arguments,
        transition: transition,
      ),
    );
  }

  /// Pop with a smooth transition effect
  void popWithTransition() {
    Navigator.of(this).pop();
  }
}

/// Types of available transitions
enum TransitionType { fade, slideInRight, slideInUp, fadeSlide, scale }

/// Helper function to build the appropriate transition
PageRoute<T> _buildTransition<T>(
  String routeName, {
  Object? arguments,
  TransitionType transition = TransitionType.slideInRight,
}) {
  // This is a placeholder - will be implemented in main.dart
  throw UnimplementedError('This should be implemented in onGenerateRoute');
}
