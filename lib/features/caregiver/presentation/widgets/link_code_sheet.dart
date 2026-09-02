import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/family_link_code.dart';

/// Bottom sheet shown to a PATIENT after generating an invite code — a live
/// countdown makes the 15-minute/one-time nature of the code visible rather
/// than something the person has to remember or take on faith.
class LinkCodeSheet extends StatefulWidget {
  final FamilyLinkCode initialCode;
  final Future<FamilyLinkCode?> Function() onRegenerate;

  const LinkCodeSheet({super.key, required this.initialCode, required this.onRegenerate});

  @override
  State<LinkCodeSheet> createState() => _LinkCodeSheetState();
}

class _LinkCodeSheetState extends State<LinkCodeSheet> {
  late FamilyLinkCode _code;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    _code = widget.initialCode;
    _startTimer();
  }

  void _startTimer() {
    _updateRemaining();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    if (!mounted) return;
    final r = _code.remaining;
    setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    final fresh = await widget.onRegenerate();
    if (!mounted) return;
    setState(() {
      if (fresh != null) _code = fresh;
      _regenerating = false;
    });
    _startTimer();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final digits = _code.code.split('');
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(height: 20),
          Text('رمز الربط', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'شارك هذا الرمز مع فرد العائلة الذي تريد ربطه بحسابك',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits
                .map(
                  (d) => Container(
                    width: 40,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            expired ? 'انتهت صلاحية هذا الرمز' : 'ينتهي بعد ${_formatDuration(_remaining)}',
            style: TextStyle(
              color: expired ? Colors.redAccent : theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (expired)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _regenerating ? null : _regenerate,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('توليد رمز جديد'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code.code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ الرمز'),
              ),
            ),
        ],
      ),
    );
  }
}
