import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _jashyDefaultAsset = 'assets/images/jashy_chibi_assistant.webp';

class AssistantHelpButton extends StatefulWidget {
  const AssistantHelpButton({
    super.key,
    required this.title,
    required this.message,
    this.messages,
    this.imageAsset = _jashyDefaultAsset,
    this.bottomOffset = 0.0,
  });

  final String title;
  final String message;
  final List<String>? messages;
  final String imageAsset;
  final double bottomOffset;

  @override
  State<AssistantHelpButton> createState() => _AssistantHelpButtonState();
}

class _AssistantHelpButtonState extends State<AssistantHelpButton> {
  bool _expanded = false;
  int _messageIndex = 0;

  List<String> get _currentMessages =>
      (widget.messages != null && widget.messages!.isNotEmpty)
          ? widget.messages!
          : [widget.message];

  String get _activeMessage {
    final list = _currentMessages;
    return list[_messageIndex % list.length];
  }

  void _nextTip() {
    setState(() {
      _messageIndex = (_messageIndex + 1) % _currentMessages.length;
    });
  }

  void _toggle() {
    setState(() {
      if (!_expanded) {
        // Al abrir, avanzar de consejo si tiene varios
        _messageIndex = (_messageIndex + 1) % _currentMessages.length;
      }
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final hasMultiple = _currentMessages.length > 1;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomOffset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_expanded) ...[
              Container(
                key: const ValueKey('jashy_help_bubble'),
                width: mobile ? 180 : 210,
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x28000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.pinkStrong),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Ocultar',
                            onPressed: _toggle,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.45,
                            ),
                      ),
                      if (hasMultiple) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _nextTip,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 3,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 12,
                                  color: AppColors.pinkStrong,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Otro tip ✨',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.pinkStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _JashyToggle(
              expanded: _expanded,
              mobile: mobile,
              imageAsset: widget.imageAsset,
              onTap: _toggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _JashyToggle extends StatelessWidget {
  const _JashyToggle({
    required this.expanded,
    required this.mobile,
    required this.onTap,
    this.imageAsset = _jashyDefaultAsset,
  });

  final bool expanded;
  final bool mobile;
  final VoidCallback onTap;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final size = expanded ? (mobile ? 102.0 : 128.0) : (mobile ? 76.0 : 92.0);
    final tooltip = expanded ? 'Cerrar ayuda de Jashy' : 'Abrir ayuda de Jashy';

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.support_agent_rounded, size: 38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
