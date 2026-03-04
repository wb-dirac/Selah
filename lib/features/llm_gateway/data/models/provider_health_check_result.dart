class ProviderHealthCheckResult {
	const ProviderHealthCheckResult({
		required this.success,
		this.message,
		this.models = const <String>[],
	});

	final bool success;
	final String? message;
	final List<String> models;
}