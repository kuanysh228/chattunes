import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: EdgeInsets.symmetric(horizontal: t.pad, vertical: t.gap),
      child: Text(text),
    );
  }
}
