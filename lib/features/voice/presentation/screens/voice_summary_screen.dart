import 'package:flutter/material.dart';

class VoiceSummaryScreen extends StatelessWidget {
  const VoiceSummaryScreen({super.key, this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('对话摘要')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '摘要',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(summary ?? '本次对话无内容'),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('← 返回对话'),
            ),
          ],
        ),
      ),
    );
  }
}
