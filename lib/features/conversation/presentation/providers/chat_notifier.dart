import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/attachment_model.dart';
import 'package:personal_ai_assistant/features/conversation/domain/conversation_service.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/knowledge_retrieval_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/orchestration/context/context_compressor.dart';
import 'package:personal_ai_assistant/orchestration/media/image_input_service.dart';
import 'package:personal_ai_assistant/orchestration/media/ocr_orchestration_service.dart';
import 'package:uuid/uuid.dart';

class DisplayMessage {
  const DisplayMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    this.parentMessageId,
    this.siblingIds = const [],
    this.activeSiblingIndex = 0,
    this.attachments = const [],
  });

  final String id;
  final ChatRole role;
  final String content;
  final bool isStreaming;
  final DateTime createdAt;

  /// For assistant messages: the user message this is a response to.
  final String? parentMessageId;

  /// IDs of all sibling branches (including this message) sharing the same parent.
  final List<String> siblingIds;

  /// Index of this message within [siblingIds]; 0 if no branches.
  final int activeSiblingIndex;

  /// Image/file attachments associated with this message.
  final List<AttachmentEntity> attachments;

  /// Whether this message has multiple branches the user can switch between.
  bool get hasBranches => siblingIds.length > 1;

  /// Whether this message has image attachments to display.
  bool get hasImages => attachments.any((a) => a.type == 'image');

  /// Whether this message is a context compression summary marker.
  /// These are rendered as separator dividers in the UI, not chat bubbles.
  bool get isSummaryMarker =>
      role == ChatRole.system && content.startsWith('[上下文摘要]');

  DisplayMessage copyWith({
    String? content,
    bool? isStreaming,
    String? parentMessageId,
    List<String>? siblingIds,
    int? activeSiblingIndex,
    List<AttachmentEntity>? attachments,
  }) {
    return DisplayMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      siblingIds: siblingIds ?? this.siblingIds,
      activeSiblingIndex: activeSiblingIndex ?? this.activeSiblingIndex,
      attachments: attachments ?? this.attachments,
    );
  }
}

class ChatState {
  const ChatState({
    this.conversationId,
    this.conversationTitle,
    this.messages = const [],
    this.isStreaming = false,
    this.error,
    this.activeBranchIndices = const {},
  });

  final String? conversationId;
  final String? conversationTitle;
  final List<DisplayMessage> messages;
  final bool isStreaming;
  final String? error;

  /// Maps parent-message-id → selected sibling index for branch switching.
  /// When a user switches branch via the BranchSwitcher, the index is
  /// stored here so [buildBranchAwareMessageList] can pick the right branch.
  final Map<String, int> activeBranchIndices;

  ChatState copyWith({
    String? conversationId,
    String? conversationTitle,
    List<DisplayMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
    Map<String, int>? activeBranchIndices,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      conversationTitle: conversationTitle ?? this.conversationTitle,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : (error ?? this.error),
      activeBranchIndices: activeBranchIndices ?? this.activeBranchIndices,
    );
  }
}

class ChatNotifier extends AsyncNotifier<ChatState> {
  bool _didInitialize = false;
  Future<void>? _initializeFuture;

  @override
  Future<ChatState> build() async {
    return const ChatState();
  }

  Future<void> initialize() async {
    if (_didInitialize) return;
    if (_initializeFuture != null) {
      await _initializeFuture;
      return;
    }

    _initializeFuture = _initializeInternal();
    try {
      await _initializeFuture;
      _didInitialize = true;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    final service = ref.read(conversationServiceProvider);
    final conversation = await service.getOrCreateActiveConversation();

    // Load ALL messages (including all branches) chronologically
    final allMessages = await service.getAllMessages(conversation.id);

    // Batch-load attachments for all messages
    final messageIds = allMessages.map((m) => m.id).toList();
    final attachmentsMap = await service.getAttachmentsForMessages(messageIds);

    // Build the branch-aware display list from raw DB entities
    final branchState = _buildBranchState(
      allMessages,
      const {},
      attachmentsMap,
    );

    final current = state.value;
    final hasLiveState =
        current != null &&
        (current.isStreaming || current.messages.isNotEmpty);

    if (hasLiveState) {
      if ((current.conversationId ?? '').isEmpty ||
          current.conversationTitle != conversation.title) {
        state = AsyncData(
          current.copyWith(
            conversationId: conversation.id,
            conversationTitle: conversation.title,
          ),
        );
      }
      return;
    }

    state = AsyncData(
      ChatState(
        conversationId: conversation.id,
        conversationTitle: conversation.title,
        messages: branchState.messages,
        activeBranchIndices: branchState.activeBranchIndices,
      ),
    );
  }

  /// Sends a new user message and streams the assistant response.
  /// The assistant response is stored with [parentMessageId] pointing
  /// to the user message, enabling future branch/regeneration.
  ///
  /// If [images] is provided, each image is saved as an [AttachmentEntity]
  /// and the image bytes are included in the LLM request for vision models.
  Future<void> sendMessage(
    String userContent,
    LlmGateway? gateway, {
    List<PickedImage> images = const [],
  }) async {
    final current = state.value;
    if (current == null) return;
    if (userContent.trim().isEmpty && images.isEmpty) return;

    final service = ref.read(conversationServiceProvider);

    String conversationId = current.conversationId ?? '';
    if (conversationId.isEmpty) {
      final conv = await service.getOrCreateActiveConversation();
      conversationId = conv.id;
    }
    await service.setActiveConversationId(conversationId);

    final conversation = await service.getConversationById(conversationId);
    final hasConversationTitle = (conversation?.title ?? '').trim().isNotEmpty;
    final existingMessages = await service.getAllMessages(conversationId);
    final hasStartedConversation = existingMessages.any(
      (m) => m.role == 'user' || m.role == 'assistant',
    );
    final shouldGenerateTitle = !hasConversationTitle && !hasStartedConversation;

    final userEntity = await service.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: userContent,
    );

    // Save image attachments to DB
    final savedAttachments = <AttachmentEntity>[];
    for (final img in images) {
      final attachment = await service.addAttachment(
        messageId: userEntity.id,
        type: 'image',
        filePath: img.filePath,
        mimeType: img.mimeType,
        width: img.width,
        height: img.height,
        sizeBytes: img.sizeBytes,
      );
      savedAttachments.add(attachment);
    }

    // Run local OCR on images to extract text for LLM context.
    // Per spec: "系统 SHALL 先调用本地 OCR 提取文字，将文字结果附加到 LLM 请求上下文"
    String effectiveContent = userContent;
    if (images.isNotEmpty) {
      final ocrService = ref.read(ocrOrchestrationServiceProvider);
      final imagePaths = images.map((img) => img.filePath).toList();
      final ocrTexts = await ocrService.extractTextFromMultiple(imagePaths);
      if (ocrTexts.isNotEmpty) {
        final ocrContext = ocrTexts.values.join('\n\n');
        effectiveContent = effectiveContent.isEmpty
            ? '[OCR 识别文字]\n$ocrContext'
            : '$effectiveContent\n\n[OCR 识别文字]\n$ocrContext';
      }
    }

    final userDisplay = DisplayMessage(
      id: userEntity.id,
      role: ChatRole.user,
      content: userContent,
      createdAt: userEntity.createdAt,
      attachments: savedAttachments,
    );

    state = AsyncData(
      current.copyWith(
        conversationId: conversationId,
        conversationTitle: current.conversationTitle ?? conversation?.title,
        messages: [...current.messages, userDisplay],
        isStreaming: true,
        clearError: true,
      ),
    );

    if (gateway == null) {
      state = AsyncData(
        state.value!.copyWith(
          isStreaming: false,
          error: '请先在设置中配置 LLM 提供商',
        ),
      );
      return;
    }

    // Convert picked images to ChatImage objects for the LLM
    final chatImages = <ChatImage>[];
    for (final img in images) {
      final bytes = await File(img.filePath).readAsBytes();
      chatImages.add(
        ChatImage(bytes: bytes, mimeType: img.mimeType ?? 'image/jpeg'),
      );
    }

    final knowledgePromptContext = await ref
        .read(knowledgeRetrievalServiceProvider)
        .buildPromptContext(
          query: effectiveContent,
          gateway: gateway,
        );

    await _streamAssistantResponse(
      gateway: gateway,
      service: service,
      conversationId: conversationId,
      parentMessageId: userEntity.id,
      userContent: userContent,
      userImages: chatImages,
      knowledgePromptContext: knowledgePromptContext,
      ocrEnrichedContent: effectiveContent != userContent
          ? effectiveContent
          : null,
      shouldGenerateTitle: shouldGenerateTitle,
    );
  }

  /// Re-generates an assistant response for the same user prompt.
  /// Creates a new branch sibling under the same [parentMessageId].
  Future<void> regenerateMessage(
    String assistantMessageId,
    LlmGateway? gateway,
  ) async {
    final current = state.value;
    if (current == null) return;
    if (current.isStreaming) return; // don't regenerate while streaming

    if (gateway == null) {
      state = AsyncData(current.copyWith(error: '请先在设置中配置 LLM 提供商'));
      return;
    }

    final service = ref.read(conversationServiceProvider);

    // Find the assistant message being regenerated
    final assistantEntity = await service.getMessageById(assistantMessageId);
    if (assistantEntity == null) return;

    final parentId = assistantEntity.parentMessageId;
    if (parentId == null) {
      // Legacy message without parent — cannot regenerate with branching
      return;
    }

    final conversationId = current.conversationId ?? '';
    if (conversationId.isEmpty) return;

    state = AsyncData(current.copyWith(isStreaming: true, clearError: true));

    await _streamAssistantResponse(
      gateway: gateway,
      service: service,
      conversationId: conversationId,
      parentMessageId: parentId,
      userContent: '',
    );
  }

  /// Switches to a different branch for a given parent message.
  /// [parentMessageId] is the user message whose assistant responses
  /// form the branch set. [siblingIndex] is the index within that set.
  void switchBranch(String parentMessageId, int siblingIndex) {
    final current = state.value;
    if (current == null) return;

    final updatedIndices = Map<String, int>.from(current.activeBranchIndices);
    updatedIndices[parentMessageId] = siblingIndex;

    // Re-build the display list with the new branch selection
    _rebuildDisplayList(updatedIndices);
  }

  void clearError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<void> startNewConversation() async {
    final service = ref.read(conversationServiceProvider);
    final conversation = await service.createConversation();
    state = AsyncData(
      ChatState(
        conversationId: conversation.id,
        conversationTitle: conversation.title,
        messages: const [],
        activeBranchIndices: const {},
      ),
    );
  }

  Future<void> renameConversationTitle(String nextTitle) async {
    final current = state.value;
    if (current == null) return;

    final conversationId = current.conversationId ?? '';
    if (conversationId.isEmpty) {
      state = AsyncData(current.copyWith(error: '当前会话不存在，无法重命名'));
      return;
    }

    final sanitizedTitle = _normalizeConversationTitleWithLimit(
      nextTitle,
      maxLength: 80,
    );
    if (sanitizedTitle.isEmpty) {
      state = AsyncData(current.copyWith(error: '标题不能为空'));
      return;
    }

    final service = ref.read(conversationServiceProvider);
    await service.updateConversationTitle(conversationId, sanitizedTitle);

    final refreshed = await service.getConversationById(conversationId);
    state = AsyncData(
      current.copyWith(
        conversationTitle: refreshed?.title ?? sanitizedTitle,
        clearError: true,
      ),
    );
  }

  Future<void> loadConversation(String conversationId) async {
    final service = ref.read(conversationServiceProvider);
    final conversation = await service.getConversationById(conversationId);
    if (conversation == null) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(error: '会话不存在或已删除'));
      }
      return;
    }

    final allMessages = await service.getAllMessages(conversation.id);
    final messageIds = allMessages.map((m) => m.id).toList();
    final attachmentsMap = await service.getAttachmentsForMessages(messageIds);
    final branchState = _buildBranchState(
      allMessages,
      const {},
      attachmentsMap,
    );

    state = AsyncData(
      ChatState(
        conversationId: conversation.id,
        conversationTitle: conversation.title,
        messages: branchState.messages,
        activeBranchIndices: branchState.activeBranchIndices,
      ),
    );

    await service.setActiveConversationId(conversation.id);
  }

  // ─── Private helpers ─────────────────────────────────────────────

  /// Default context window size used when the model does not report one.
  static const _defaultContextWindowTokens = 128000;
  static final RegExp _titleTagPattern = RegExp(
    r'^\s*\[TITLE\]\s*(.{1,80}?)\s*\[/TITLE\]\s*',
    dotAll: true,
  );

  /// Streams an LLM response, saves to DB with [parentMessageId], and
  /// rebuilds the branch-aware display list on completion.
  ///
  /// Before calling the LLM, the conversation history is checked against
  /// the context window via [ContextCompressor]. If compression occurs,
  /// a system-role summary message is persisted in the DB so the UI can
  /// render the "上下文已压缩" separator.
  ///
  /// If [userImages] is provided, the images are attached to the last
  /// user message in the history for multimodal LLM input.
  ///
  /// If [ocrEnrichedContent] is provided, it replaces the content of the
  /// last user message in the LLM history so OCR-extracted text is included
  /// in the context sent to the model. The display message retains the
  /// original user text (OCR text is invisible to the user in the chat UI).
  Future<void> _streamAssistantResponse({
    required LlmGateway gateway,
    required ConversationService service,
    required String conversationId,
    required String parentMessageId,
    required String userContent,
    List<ChatImage> userImages = const [],
    String? knowledgePromptContext,
    String? ocrEnrichedContent,
    bool shouldGenerateTitle = false,
    int? contextWindowTokens,
  }) async {
    try {
      // Build history from currently displayed messages (branch-aware)
      final history = (state.value?.messages ?? []).map((m) {
        return ChatMessage(role: m.role, content: m.content);
      }).toList();

      // Enrich the last user message with OCR-extracted text if available
      if (ocrEnrichedContent != null && history.isNotEmpty) {
        final lastIdx = history.lastIndexWhere((m) => m.role == ChatRole.user);
        if (lastIdx >= 0) {
          history[lastIdx] = ChatMessage(
            role: history[lastIdx].role,
            content: ocrEnrichedContent,
            images: history[lastIdx].images,
          );
        }
      }

      // Attach images to the last user message if provided
      if (userImages.isNotEmpty && history.isNotEmpty) {
        final lastIdx = history.lastIndexWhere((m) => m.role == ChatRole.user);
        if (lastIdx >= 0) {
          history[lastIdx] = ChatMessage(
            role: history[lastIdx].role,
            content: history[lastIdx].content,
            images: userImages,
          );
        }
      }

      // ── Context compression ──────────────────────────────────────
      final compressor = ref.read(contextCompressorProvider);
      final windowSize = contextWindowTokens ?? _defaultContextWindowTokens;

      final compressionResult = await compressor.compressIfNeeded(
        messages: history,
        contextWindowTokens: windowSize,
        gateway: gateway,
      );

      // If compression occurred, persist the summary as a system message
      // so it appears in future loads and the UI can show the separator.
      if (compressionResult.wasCompressed &&
          compressionResult.summaryText != null) {
        await service.addMessage(
          conversationId: conversationId,
          role: 'system',
          content: '[上下文摘要] ${compressionResult.summaryText}',
        );
      }

      final effectiveHistory = <ChatMessage>[
        if (shouldGenerateTitle)
          const ChatMessage(
            role: ChatRole.system,
            content:
                '你是会话标题助手。请在回复最开头严格输出一行 [TITLE]标题[/TITLE]，标题不超过20个汉字；随后紧接着输出正常回答内容。除这一行外，不要解释标题规则。',
          ),
        if (knowledgePromptContext != null && knowledgePromptContext.trim().isNotEmpty)
          ChatMessage(
            role: ChatRole.system,
            content: knowledgePromptContext,
          ),
        ...compressionResult.messages,
      ];

      // ── Stream assistant response ────────────────────────────────
      final assistantMsgId = const Uuid().v4();
      final streamingMsg = DisplayMessage(
        id: assistantMsgId,
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        isStreaming: true,
        parentMessageId: parentMessageId,
      );

      state = AsyncData(
        state.value!.copyWith(
          messages: [...(state.value?.messages ?? []), streamingMsg],
        ),
      );

      final buffer = StringBuffer();
      await for (final chunk in gateway.chat(effectiveHistory)) {
        buffer.write(chunk.textDelta);
        final visibleContent = _stripTitleTagForDisplay(buffer.toString());
        final updated = streamingMsg.copyWith(
          content: visibleContent,
          isStreaming: true,
        );
        final msgs = List<DisplayMessage>.from(
          state.value?.messages ?? [],
        );
        final idx = msgs.indexWhere((m) => m.id == assistantMsgId);
        if (idx >= 0) msgs[idx] = updated;
        state = AsyncData(state.value!.copyWith(messages: msgs));
      }

      final parsed = _extractTitleAndSanitizeContent(
        raw: buffer.toString(),
        fallbackUserContent: userContent,
      );

      if (shouldGenerateTitle) {
        final fallbackTitle = _fallbackTitleFromInputs(
          userInput: userContent,
          assistantContent: parsed.content,
        );
        final resolvedTitle = _normalizeConversationTitleWithLimit(
          parsed.title ?? fallbackTitle,
          maxLength: 20,
        );
        final appliedTitle = await _updateConversationTitleIfEmpty(
          service: service,
          conversationId: conversationId,
          title: resolvedTitle,
        );
        if (appliedTitle != null && state.value != null) {
          state = AsyncData(
            state.value!.copyWith(conversationTitle: appliedTitle),
          );
        }
      }

      // Persist the completed assistant message with parent link
      final savedAssistant = await service.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: parsed.content,
        parentMessageId: parentMessageId,
      );

      // Fast path: for normal single-branch flow, avoid full DB reload/rebuild.
      // Keep UI state incremental for better performance.
      final siblingCount = (await service.getSiblings(parentMessageId)).length;
      final shouldRebuildFromDb =
          compressionResult.wasCompressed || siblingCount > 1;

      if (!shouldRebuildFromDb) {
        final current = state.value;
        if (current != null) {
          final msgs = List<DisplayMessage>.from(current.messages);
          final idx = msgs.indexWhere((m) => m.id == assistantMsgId);
          if (idx >= 0) {
            msgs[idx] = DisplayMessage(
              id: savedAssistant.id,
              role: ChatRole.assistant,
              content: parsed.content,
              createdAt: savedAssistant.createdAt,
              isStreaming: false,
              parentMessageId: parentMessageId,
            );
          }
          state = AsyncData(
            current.copyWith(
              messages: msgs,
              isStreaming: false,
            ),
          );
        }
        return;
      }

      // Reload all messages from DB and rebuild display with branch info
      final allMessages = await service.getAllMessages(conversationId);

      // After regeneration, select the newest sibling for this parent
      final updatedIndices = Map<String, int>.from(
        state.value?.activeBranchIndices ?? {},
      );
      final siblings = allMessages
          .where((m) => m.parentMessageId == parentMessageId)
          .toList();
      if (siblings.isNotEmpty) {
        updatedIndices[parentMessageId] = siblings.length - 1;
      }

      final messageIds = allMessages.map((m) => m.id).toList();
      final attachmentsMap = await service.getAttachmentsForMessages(
        messageIds,
      );
      final branchState = _buildBranchState(
        allMessages,
        updatedIndices,
        attachmentsMap,
      );

      final previousMessages = state.value?.messages ?? const <DisplayMessage>[];
      final resolvedMessages =
          branchState.messages.isEmpty && previousMessages.isNotEmpty
          ? previousMessages
          : branchState.messages;

      state = AsyncData(
        ChatState(
          conversationId: conversationId,
          messages: resolvedMessages,
          isStreaming: false,
          activeBranchIndices: branchState.activeBranchIndices,
        ),
      );
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(isStreaming: false, error: e.toString()),
      );
    }
  }

  String _stripTitleTagForDisplay(String raw) {
    final trimmedLeft = raw.trimLeft();
    if (!trimmedLeft.startsWith('[TITLE]')) {
      return raw;
    }

    final end = trimmedLeft.indexOf('[/TITLE]');
    if (end < 0) {
      return '';
    }
    final contentStart = end + '[/TITLE]'.length;
    return trimmedLeft.substring(contentStart).trimLeft();
  }

  _ParsedAssistantReply _extractTitleAndSanitizeContent({
    required String raw,
    required String fallbackUserContent,
  }) {
    final match = _titleTagPattern.firstMatch(raw);
    if (match == null) {
      return _ParsedAssistantReply(content: raw);
    }

    final extractedTitle = match.group(1)?.trim() ?? '';
    final normalizedTitle = extractedTitle.isEmpty
        ? _fallbackTitleFromUserInput(fallbackUserContent)
        : extractedTitle;
    final content = raw.replaceFirst(match.group(0)!, '').trimLeft();

    return _ParsedAssistantReply(
      title: normalizedTitle,
      content: content,
    );
  }

  String _fallbackTitleFromInputs({
    required String userInput,
    required String assistantContent,
  }) {
    final text = userInput.trim().isNotEmpty
        ? userInput.trim()
        : assistantContent.trim();
    if (text.isEmpty) {
      return '新对话';
    }

    final firstLine = text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => text);
    final sanitized = firstLine.replaceAll(RegExp(r'\s+'), ' ');
    return _normalizeConversationTitleWithLimit(sanitized, maxLength: 20);
  }

  String _normalizeConversationTitleWithLimit(
    String rawTitle, {
    required int maxLength,
  }) {
    final compact = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return '';
    }

    if (compact.length <= maxLength) {
      return compact;
    }

    return '${compact.substring(0, maxLength)}…';
  }

  Future<String?> _updateConversationTitleIfEmpty({
    required ConversationService service,
    required String conversationId,
    required String title,
  }) async {
    final conversation = await service.getConversationById(conversationId);
    if (conversation == null) return null;
    final existingTitle = (conversation.title ?? '').trim();
    if (existingTitle.isNotEmpty) return existingTitle;

    await service.updateConversationTitle(conversationId, title);
    return title;
  }

  String _fallbackTitleFromUserInput(String userInput) {
    final text = userInput.trim();
    if (text.isEmpty) {
      return '新对话';
    }
    final compact = text.replaceAll(RegExp(r'\s+'), ' ');
    return compact.length <= 20 ? compact : '${compact.substring(0, 20)}…';
  }

  /// Reloads from DB and rebuilds display with given branch selections.
  Future<void> _rebuildDisplayList(Map<String, int> branchIndices) async {
    final current = state.value;
    if (current == null) return;

    final conversationId = current.conversationId ?? '';
    if (conversationId.isEmpty) return;

    final service = ref.read(conversationServiceProvider);
    final allMessages = await service.getAllMessages(conversationId);
    final messageIds = allMessages.map((m) => m.id).toList();
    final attachmentsMap = await service.getAttachmentsForMessages(messageIds);
    final branchState = _buildBranchState(
      allMessages,
      branchIndices,
      attachmentsMap,
    );

    state = AsyncData(
      current.copyWith(
        messages: branchState.messages,
        activeBranchIndices: branchState.activeBranchIndices,
      ),
    );
  }

  /// Core algorithm: from a flat list of all messages (all branches),
  /// build a linear display list by selecting one branch per parent.
  ///
  /// Algorithm:
  /// 1. Group assistant messages by parentMessageId
  /// 2. Walk messages chronologically
  /// 3. For user messages: always include
  /// 4. For assistant messages with a parent: only include the selected
  ///    branch sibling. Attach sibling metadata for the BranchSwitcher.
  /// 5. For legacy assistant messages (no parent): always include
  ///
  /// [attachmentsMap] maps message ID → list of attachments, used to
  /// populate [DisplayMessage.attachments].
  _BranchBuildResult _buildBranchState(
    List<dynamic> allMessages,
    Map<String, int> requestedIndices,
    Map<String, List<AttachmentEntity>> attachmentsMap,
  ) {
    // Group assistant siblings by parent_message_id
    final Map<String, List<dynamic>> siblingGroups = {};
    for (final msg in allMessages) {
      final parentId = msg.parentMessageId as String?;
      if (parentId != null) {
        siblingGroups.putIfAbsent(parentId, () => []);
        siblingGroups[parentId]!.add(msg);
      }
    }

    final effectiveIndices = Map<String, int>.from(requestedIndices);
    final displayMessages = <DisplayMessage>[];
    final processedParents = <String>{};

    for (final msg in allMessages) {
      final role = msg.role as String;
      final parentId = msg.parentMessageId as String?;

      if (role == 'user' || parentId == null) {
        // User messages and legacy assistant messages (no parent)
        final msgId = msg.id as String;
        displayMessages.add(
          DisplayMessage(
            id: msgId,
            role: _roleFromString(role),
            content: msg.content as String,
            createdAt: msg.createdAt as DateTime,
            attachments: attachmentsMap[msgId] ?? const [],
          ),
        );
      } else {
        // Assistant message with a parent — process only once per parent group
        if (processedParents.contains(parentId)) continue;
        processedParents.add(parentId);

        final siblings = siblingGroups[parentId] ?? [msg];
        final selectedIndex = (effectiveIndices[parentId] ?? 0).clamp(
          0,
          siblings.length - 1,
        );
        effectiveIndices[parentId] = selectedIndex;

        final selected = siblings[selectedIndex];
        final selectedId = selected.id as String;
        final siblingIds = siblings.map((s) => s.id as String).toList();

        displayMessages.add(
          DisplayMessage(
            id: selectedId,
            role: ChatRole.assistant,
            content: selected.content as String,
            createdAt: selected.createdAt as DateTime,
            parentMessageId: parentId,
            siblingIds: siblingIds,
            activeSiblingIndex: selectedIndex,
            attachments: attachmentsMap[selectedId] ?? const [],
          ),
        );
      }
    }

    return _BranchBuildResult(
      messages: displayMessages,
      activeBranchIndices: effectiveIndices,
    );
  }

  ChatRole _roleFromString(String role) {
    switch (role) {
      case 'user':
        return ChatRole.user;
      case 'assistant':
        return ChatRole.assistant;
      case 'system':
        return ChatRole.system;
      default:
        return ChatRole.user;
    }
  }
}

/// Internal result of [_buildBranchState].
class _BranchBuildResult {
  const _BranchBuildResult({
    required this.messages,
    required this.activeBranchIndices,
  });

  final List<DisplayMessage> messages;
  final Map<String, int> activeBranchIndices;
}

class _ParsedAssistantReply {
  const _ParsedAssistantReply({
    this.title,
    required this.content,
  });

  final String? title;
  final String content;
}

final chatNotifierProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
