import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _jashyDefaultAsset = 'assets/images/jashy_chibi_assistant.webp';

class AssistantHelpButton extends StatefulWidget {
  const AssistantHelpButton({
    super.key,
    required this.title,
    required this.message,
    this.imageAsset = _jashyDefaultAsset,
    this.bottomOffset = 0.0,
  });

  final String title;
  final String message;
  final String imageAsset;
  final double bottomOffset;

  @override
  State<AssistantHelpButton> createState() => _AssistantHelpButtonState();
}

class _AssistantHelpButtonState extends State<AssistantHelpButton> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;

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
                        widget.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.45,
                            ),
                      ),
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
