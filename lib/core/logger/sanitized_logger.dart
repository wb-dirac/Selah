import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';

class SanitizedLogger implements AppLogger {
	SanitizedLogger({AppLogger? delegate}) : _delegate = delegate;

	static final List<RegExp> _sensitivePatterns = <RegExp>[
		RegExp(r'sk-[A-Za-z0-9\-_]{20,}'),
		RegExp(r'sk-ant-[A-Za-z0-9\-_]{20,}'),
		RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
		RegExp(r'\b1[3-9]\d{9}\b'),
		RegExp(r'\b[6-9]\d{15}\b'),
		RegExp(
			r'\b[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])\d{2}\d{3}[0-9xX]\b',
		),
	];

	final AppLogger? _delegate;

	@override
	void info(String message, {Map<String, Object?>? context}) {
		_delegate?.info(_sanitize(message), context: _sanitizeContext(context));
	}

	@override
	void warning(String message, {Map<String, Object?>? context}) {
		_delegate?.warning(_sanitize(message), context: _sanitizeContext(context));
	}

	@override
	void error(
		String message, {
		Object? error,
		StackTrace? stackTrace,
		Map<String, Object?>? context,
	}) {
		_delegate?.error(
			_sanitize(message),
			error: error == null ? null : _sanitize(error.toString()),
			stackTrace: stackTrace,
			context: _sanitizeContext(context),
		);
	}

	String sanitize(String input) {
		return _sanitize(input);
	}

	String _sanitize(String input) {
		var current = input;
		for (final pattern in _sensitivePatterns) {
			current = current.replaceAll(pattern, '[REDACTED]');
		}
		return current;
	}

	Map<String, Object?>? _sanitizeContext(Map<String, Object?>? context) {
		if (context == null) {
			return null;
		}

		return context.map(
			(key, value) => MapEntry(
				key,
				value == null ? null : _sanitize(value.toString()),
			),
		);
	}
}

final sanitizedLoggerProvider = Provider<SanitizedLogger>((ref) {
	return SanitizedLogger();
});