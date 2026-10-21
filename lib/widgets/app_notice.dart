import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppNoticeTone { success, info, error }

OverlayEntry? _activeAppNotice;

void showAppNotice(
  BuildContext context,
  String message, {
  AppNoticeTone tone = AppNoticeTone.success,
  Duration duration = const Duration(milliseconds: 2400),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final previous = _activeAppNotice;
  if (previous?.mounted ?? false) previous!.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppNotice(
      message: message,
      tone: tone,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      onFinished: () {
        if (entry.mounted) entry.remove();
        if (identical(_activeAppNotice, entry)) _activeAppNotice = null;
      },
    ),
  );
  _activeAppNotice = entry;
  overlay.insert(entry);
}

class _AppNotice extends StatefulWidget {
  const _AppNotice({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onFinished,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppNoticeTone tone;
  final Duration duration;
  final VoidCallback onFinished;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppNotice> createState() => _AppNoticeState();
}

class _AppNoticeState extends State<_AppNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    )..forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = switch (widget.tone) {
      AppNoticeTone.success => (Icons.check_rounded, AppColors.whatsapp),
      AppNoticeTone.info => (Icons.info_outline_rounded, AppColors.pinkStrong),
      AppNoticeTone.error => (Icons.error_outline_rounded, AppColors.error),
    };
    final top = MediaQuery.paddingOf(context).top + 16;
    final width = math.min(340.0, MediaQuery.sizeOf(context).width - 24);

    return Positioned(
      top: top,
      right: 12,
      width: width,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(.12, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: Semantics(
            liveRegion: true,
            label: widget.message,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 19, color: Colors.white),
                        ),
                        const SizedBox(width: 11),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              widget.onAction!();
                              _dismiss();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
