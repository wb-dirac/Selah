class EmbeddingVector {
	const EmbeddingVector({
		required this.values,
		this.model,
	});

	final List<double> values;
	final String? model;
}