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
          IconButton(
            tooltip: 'Reducir cantidad',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDecrease,
            icon: const Icon(Icons.remove, size: 19),
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
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _focus.unfocus(),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar cantidad',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onIncrease,
            icon: const Icon(Icons.add, size: 19),
          ),
        ],
      ),
    );
  }
}
