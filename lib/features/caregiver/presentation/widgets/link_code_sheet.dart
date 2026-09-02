import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/family_link_code.dart';

class LinkCodeSheet extends StatefulWidget {
  final FamilyLinkCode initialCode;
  final Future<FamilyLinkCode?> Function() onRegenerate;

  const LinkCodeSheet({
    super.key,
    required this.initialCode,
    required this.onRegenerate,
  });

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (!mounted) return;
    final remaining = _code.remaining;
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final expired = _remaining == Duration.zero;
    final theme = Theme.of(context);

    final codeBoxes = _code.code.split('').map<Widget>((digit) {
      return Container(
        width: 40,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
      );
    }).toList();

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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(l.linkCode, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l.linkCodeHint,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: codeBoxes,
          ),
          const SizedBox(height: 16),
          Text(
            expired
                ? l.codeExpired
                : l.expiresIn(_formatDuration(_remaining)),
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
                label: Text(l.generateNewCode),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.codeCopied)),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(l.copyCode),
              ),
            ),
        ],
      ),
    );
  }
}
