import 'dart:convert';

/// JSON Schema primitive type for tool parameters.
enum ToolParamType { string, number, boolean, array, object }

/// A single property in a JSON Schema object, describing one tool parameter.
class ToolParamProperty {
  const ToolParamProperty({
    required this.type,
    required this.description,
    this.enumValues,
    this.itemsType,
  });

  final ToolParamType type;
  final String description;

  /// Allowed values (only for [ToolParamType.string]).
  final List<String>? enumValues;

  /// Element type for [ToolParamType.array].
  final ToolParamType? itemsType;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type.name,
      'description': description,
    };
    if (enumValues != null && enumValues!.isNotEmpty) {
      json['enum'] = enumValues;
    }
    if (type == ToolParamType.array && itemsType != null) {
      json['items'] = {'type': itemsType!.name};
    }
    return json;
  }
}

/// JSON Schema object describing the parameters of a tool.
class ToolParameterSchema {
  const ToolParameterSchema({
    this.properties = const {},
    this.required = const [],
  });

  final Map<String, ToolParamProperty> properties;
  final List<String> required;

  Map<String, dynamic> toJson() => {
        'type': 'object',
        'properties': {
          for (final entry in properties.entries) entry.key: entry.value.toJson(),
        },
        if (required.isNotEmpty) 'required': required,
      };
}

/// A function/tool specification passed to an LLM for function calling.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    this.parameters = const ToolParameterSchema(),
  });

  /// Function name — must match the tool ID used by [ToolBridgeExecutor].
  final String name;
  final String description;
  final ToolParameterSchema parameters;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters.toJson(),
      };
}

/// A single tool call requested by the LLM in a [ChatChunk].
class ToolCallRequest {
  const ToolCallRequest({
    required this.callId,
    required this.name,
    required this.arguments,
    this.thoughtSignature,
  });

  /// Provider-issued call identifier, used to match the result back to this call.
  final String callId;

  /// The tool/function name as registered in [ToolBridgeExecutor].
  final String name;

  /// Parsed arguments map.
  final Map<String, dynamic> arguments;

  /// Opaque signature emitted by Gemini thinking models alongside a
  /// [functionCall] part.  Must be round-tripped verbatim in the conversation
  /// history so the model can correlate its internal reasoning with the call.
  /// Null for all non-Gemini-thinking providers.
  final String? thoughtSignature;

  /// Parses a raw JSON-string argument payload into a [ToolCallRequest].
  /// Returns an empty arguments map on parse failure rather than throwing.
  factory ToolCallRequest.fromArgumentsJson({
    required String callId,
    required String name,
    required String argumentsJson,
  }) {
    Map<String, dynamic> args;
    if (argumentsJson.trim().isEmpty) {
      args = const {};
    } else {
      try {
        final decoded = jsonDecode(argumentsJson);
        args = decoded is Map<String, dynamic> ? decoded : const {};
      } catch (_) {
        args = const {};
      }
    }
    return ToolCallRequest(callId: callId, name: name, arguments: args);
  }
}
