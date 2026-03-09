import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/contact_alias_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/pii_detection_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/privacy_preferences_service.dart';

class OutboundPrivacyReview {
  const OutboundPrivacyReview({
    required this.originalText,
    required this.aliasedText,
    required this.sanitizedText,
    required this.aliases,
    required this.piiMatches,
  });

  final String originalText;
  final String aliasedText;
  final String sanitizedText;
  final List<ContactAliasEntry> aliases;
  final List<PiiMatch> piiMatches;

  bool get hasSensitiveData => piiMatches.isNotEmpty;
  bool get hasAliases => aliases.isNotEmpty;
}

class OutboundPrivacyGuardService {
  OutboundPrivacyGuardService({
    required PrivacyPreferencesService privacyPreferencesService,
    required PiiDetectionService piiDetectionService,
    required ContactAliasService contactAliasService,
  }) : _privacyPreferencesService = privacyPreferencesService,
       _piiDetectionService = piiDetectionService,
       _contactAliasService = contactAliasService;

  final PrivacyPreferencesService _privacyPreferencesService;
  final PiiDetectionService _piiDetectionService;
  final ContactAliasService _contactAliasService;

  Future<OutboundPrivacyReview> review({
    required String? conversationId,
    required String originalText,
  }) async {
    final preferences = await _privacyPreferencesService.load();
    final aliasResult = preferences.replaceContactNamesEnabled
        ? await _contactAliasService.sanitizeText(
            conversationId: conversationId,
            text: originalText,
          )
        : ContactAliasResult(
            originalText: originalText,
            sanitizedText: originalText,
            aliases: const <ContactAliasEntry>[],
          );

    final detection = preferences.piiDetectionEnabled
        ? _piiDetectionService.detect(aliasResult.sanitizedText)
        : PiiDetectionResult(
            originalText: aliasResult.sanitizedText,
            sanitizedText: aliasResult.sanitizedText,
            matches: const <PiiMatch>[],
          );

    return OutboundPrivacyReview(
      originalText: originalText,
      aliasedText: aliasResult.sanitizedText,
      sanitizedText: detection.sanitizedText,
      aliases: aliasResult.aliases,
      piiMatches: detection.matches,
    );
  }
}

final outboundPrivacyGuardServiceProvider = Provider<OutboundPrivacyGuardService>((
  ref,
) {
  return OutboundPrivacyGuardService(
    privacyPreferencesService: ref.watch(privacyPreferencesServiceProvider),
    piiDetectionService: ref.watch(piiDetectionServiceProvider),
    contactAliasService: ref.watch(contactAliasServiceProvider),
  );
});
