abstract class AppLogger {
	void info(String message, {Map<String, Object?>? context});
	void warning(String message, {Map<String, Object?>? context});
	void error(
		String message, {
		Object? error,
		StackTrace? stackTrace,
		Map<String, Object?>? context,
	});
}