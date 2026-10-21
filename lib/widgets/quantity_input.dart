import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact quantity field that also accepts a typed number.
class QuantityInput extends StatefulWidget {
  const QuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.onDecrease,
    this.onIncrease,
    this.backgroundColor,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final Color? backgroundColor;

  @override
  State<QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final entered = int.tryParse(_controller.text);
    if (entered != null && entered >= 1 && entered <= 100000) {
      widget.onChanged(entered);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _controller.text = '${widget.value}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            tooltip: 'Reducir cantidad',
            icon: Icons.remove,
            onTap: widget.onDecrease,
            onLongPress: widget.onDecrease == null
                ? null
                : () => widget.onChanged(
                    widget.value > 10 ? widget.value - 10 : 1,
                  ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _focus.unfocus(),
            ),
          ),
          _QuantityButton(
            tooltip: 'Aumentar cantidad',
            icon: Icons.add,
            onTap: widget.onIncrease,
            onLongPress: widget.onIncrease == null
                ? null
                : () => widget.onChanged(widget.value + 10),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.tooltip,
    required this.icon,
    this.onTap,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: '$tooltip. Mantén presionado para cambiar de 10 en 10.',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 44,
            height: 46,
            child: Icon(
              icon,
              size: 19,
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}
