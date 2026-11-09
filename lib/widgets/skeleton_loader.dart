import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

bool get _isInTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// A subtle shimmering placeholder box for loading states.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor = const Color(0xFFEDE8E0),
    this.highlightColor = const Color(0xFFF8F6F2),
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_isInTest) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * value - 0.5, -0.3),
              end: Alignment(-1.0 + 2.0 * value + 0.5, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton used inside [ProductVisual] while network images are downloading.
class ProductVisualSkeleton extends StatelessWidget {
  const ProductVisualSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerSkeleton(
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
      baseColor: Color(0xFFF0ECE4),
      highlightColor: Color(0xFFFAF9F6),
    );
  }
}

/// A skeleton resembling a [ProductCard] for instant perceived performance.
class CatalogCardSkeleton extends StatelessWidget {
  const CatalogCardSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cardRadius = compact ? 14.0 : 18.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: const Color(0xFFF0EDE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: ProductVisualSkeleton()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              compact ? 8 : 10,
              compact ? 10 : 12,
              compact ? 10 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerSkeleton(
                  width: compact ? 100 : 140,
                  height: compact ? 13 : 15,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                ShimmerSkeleton(
                  width: compact ? 65 : 85,
                  height: compact ? 11 : 13,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full grid of skeleton cards matching the catalog layout.
class CatalogGridSkeleton extends StatelessWidget {
  const CatalogGridSkeleton({
    super.key,
    this.itemCount = 8,
    this.compact = false,
  });

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final isCompact = compact || viewportWidth < 640;
        final horizontalPadding = viewportWidth > 1180
            ? (viewportWidth - 1180) / 2 + 20
            : 20.0;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            24,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isCompact ? 210 : 260,
            mainAxisExtent: isCompact ? 250 : 304,
            crossAxisSpacing: isCompact ? 12 : 16,
            mainAxisSpacing: isCompact ? 12 : 16,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) =>
              CatalogCardSkeleton(compact: isCompact),
        );
      },
    );
  }
}
