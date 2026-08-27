import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A row of six single-digit boxes for entering a verification code.
class OtpCodeRow extends StatefulWidget {
  const OtpCodeRow({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<OtpCodeRow> createState() => _OtpCodeRowState();
}

class _OtpCodeRowState extends State<OtpCodeRow> {
  static const _length = 6;
  late final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes = List.generate(_length, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _emitCode() {
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _emitCode();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (i) {
        return SizedBox(
          width: 44,
          height: 56,
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) => _onDigitChanged(i, value),
          ),
        );
      }),
    );
  }
}
