import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';

abstract class LlmGateway {
	Stream<ChatChunk> chat(
		List<ChatMessage> messages, {
		LlmChatOptions options = const LlmChatOptions(),
	});

	Future<EmbeddingVector> embed(
		String text, {
		String? model,
	});

	Future<List<LlmModelInfo>> listModels();
}