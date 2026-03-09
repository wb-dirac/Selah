import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';

Future<bool> showToolCallL1Dialog({
  required BuildContext context,
  required ToolDefinition definition,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _L1ConfirmationDialog(definition: definition),
  );
  return result ?? false;
}

Future<bool> showToolCallL2Dialog({
  required BuildContext context,
  required ToolDefinition definition,
  Map<String, dynamic>? arguments,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _L2ConfirmationDialog(
      definition: definition,
      arguments: arguments,
    ),
  );
  return result ?? false;
}

Future<bool> showToolCallL3Dialog({
  required BuildContext context,
  required ToolDefinition definition,
  Map<String, dynamic>? arguments,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _L3ConfirmationDialog(
      definition: definition,
      arguments: arguments,
    ),
  );
  return result ?? false;
}

class _L1ConfirmationDialog extends StatelessWidget {
  const _L1ConfirmationDialog({required this.definition});

  final ToolDefinition definition;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.security, size: 36),
      title: const Text('工具调用授权'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            definition.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(definition.description),
          const SizedBox(height: 12),
          Text(
            '允许后将不再询问。您可以在「工具权限」设置中随时撤销授权。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('允许'),
        ),
      ],
    );
  }
}

class _L2ConfirmationDialog extends StatelessWidget {
  const _L2ConfirmationDialog({
    required this.definition,
    this.arguments,
  });

  final ToolDefinition definition;
  final Map<String, dynamic>? arguments;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 36),
      title: const Text('工具调用确认'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            definition.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(definition.description),
          if (arguments != null && arguments!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '参数摘要',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            _ArgumentsSummary(arguments: arguments!),
          ],
          const SizedBox(height: 12),
          Text(
            '此工具每次调用均需您确认。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认执行'),
        ),
      ],
    );
  }
}

class _L3ConfirmationDialog extends StatelessWidget {
  const _L3ConfirmationDialog({
    required this.definition,
    this.arguments,
  });

  final ToolDefinition definition;
  final Map<String, dynamic>? arguments;

  @override
  Widget build(BuildContext context) {
    final prettyArgs = arguments != null
        ? const JsonEncoder.withIndent('  ').convert(arguments)
        : null;

    return AlertDialog(
      icon: const Icon(Icons.preview_rounded, size: 36),
      title: const Text('工具调用完整预览'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              definition.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(definition.description),
            if (prettyArgs != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '完整参数',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectionArea(
                  child: Text(
                    prettyArgs,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '此操作将立即执行，请仔细核对以上内容。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认执行'),
        ),
      ],
    );
  }
}

class _ArgumentsSummary extends StatelessWidget {
  const _ArgumentsSummary({required this.arguments});

  final Map<String, dynamic> arguments;

  @override
  Widget build(BuildContext context) {
    final entries = arguments.entries.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        final valueStr = entry.value?.toString() ?? 'null';
        final truncated = valueStr.length > 60
            ? '${valueStr.substring(0, 57)}...'
            : valueStr;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${entry.key}: ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  truncated,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
