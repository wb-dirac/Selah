import 'dart:convert';

class ProviderConfiguration {
  const ProviderConfiguration({
    required this.providerId,
    required this.displayName,
    this.baseUrl,
    this.defaultModel,
    this.enabled = true,
    this.apiKey = '',
  });

  final String providerId;
  final String displayName;
  final String? baseUrl;
  final String? defaultModel;
  final bool enabled;
  final String apiKey;

  ProviderConfiguration copyWith({
    String? providerId,
    String? displayName,
    String? baseUrl,
    String? defaultModel,
    bool? enabled,
    String? apiKey,
  }) {
    return ProviderConfiguration(
      providerId: providerId ?? this.providerId,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  Map<String, Object?> toExportJson() {
    return {
      'provider_id': providerId,
      'display_name': displayName,
      'base_url': baseUrl,
      'default_model': defaultModel,
      'enabled': enabled,
      'api_key': '',
    };
  }

  factory ProviderConfiguration.fromJson(Map<String, dynamic> json) {
    return ProviderConfiguration(
      providerId: json['provider_id'] as String,
      displayName: json['display_name'] as String,
      baseUrl: json['base_url'] as String?,
      defaultModel: json['default_model'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      apiKey: '',
    );
  }
}

class ProviderConfigImportExportService {
  const ProviderConfigImportExportService();

  String exportConfigurations(List<ProviderConfiguration> configurations) {
    final payload = {
      'providers': configurations.map((c) => c.toExportJson()).toList(growable: false),
    };
    return jsonEncode(payload);
  }

  List<ProviderConfiguration> importConfigurations(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final providers = decoded['providers'] as List<dynamic>? ?? const [];
    return providers
        .whereType<Map<String, dynamic>>()
        .map(ProviderConfiguration.fromJson)
        .map((config) => config.copyWith(apiKey: ''))
        .toList(growable: false);
  }
}