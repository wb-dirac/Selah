import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/clear_all_data_service.dart';

class ClearAllDataDialog extends ConsumerWidget {
	const ClearAllDataDialog({super.key});

	/// Shows a two-step confirmation dialog and clears all data on final confirm.
	static Future<void> show(BuildContext context, WidgetRef ref) async {
		final continuePressed = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('清除所有数据'),
				content: const Text(
					'此操作将永久删除所有本地数据，包括对话历史、文档片段及配置信息。\n\n'
					'此操作不可撤销，请谨慎操作。',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(context).pop(false),
						child: const Text('取消'),
					),
					TextButton(
						onPressed: () => Navigator.of(context).pop(true),
						child: const Text('继续'),
					),
				],
			),
		);

		if (continuePressed != true || !context.mounted) return;

		final confirmed = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('确认清除'),
				content: const Text('您确定要永久删除所有本地数据吗？'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(context).pop(false),
						child: const Text('取消'),
					),
					TextButton(
						style: TextButton.styleFrom(
							foregroundColor: Colors.red,
						),
						onPressed: () => Navigator.of(context).pop(true),
						child: const Text('永久删除'),
					),
				],
			),
		);

		if (confirmed != true || !context.mounted) return;

		try {
			await ref.read(clearAllDataServiceProvider).clearAll();
		} catch (e, st) {
			// Service already logs internally; rethrow to allow caller to handle.
			Error.throwWithStackTrace(e, st);
		}

		if (!context.mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('所有数据已清除')),
		);
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return const SizedBox.shrink();
	}
}
