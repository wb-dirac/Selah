import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownMessageContent extends StatelessWidget {
	const MarkdownMessageContent({super.key, required this.content});

	final String content;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final codeBackground = theme.colorScheme.surfaceContainerHighest;

		return MarkdownBody(
			data: content,
			styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
				code: TextStyle(
					fontFamily: 'monospace',
					fontSize: 13,
					backgroundColor: codeBackground,
					color: theme.colorScheme.onSurface,
				),
				codeblockDecoration: BoxDecoration(
					color: codeBackground,
					borderRadius: BorderRadius.circular(8),
					border: Border.all(
						color: theme.dividerColor,
					),
				),
				codeblockPadding: const EdgeInsets.all(12),
			),
		);
	}
}
