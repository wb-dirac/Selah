import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_gateway_resolver.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/widgets/branch_switcher.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/widgets/markdown_message_content.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/widgets/generative_ui_message_content.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/outbound_privacy_guard_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/privacy_preferences_service.dart';
import 'package:personal_ai_assistant/features/privacy/presentation/widgets/privacy_review_dialogs.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_bridge_executor.dart';
import 'package:personal_ai_assistant/orchestration/media/file_input_service.dart';
import 'package:personal_ai_assistant/orchestration/media/image_input_service.dart';
import 'package:personal_ai_assistant/presentation/screens/widgets/feature_disabled_view.dart';
import 'package:record/record.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<PickedImage> _stagedImages = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatNotifierProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _stagedImages.isEmpty) return;

    final resolver = ref.read(chatGatewayResolverProvider);
    final selection = await resolver.resolveSelectionForInput(
      userContent: text,
      hasImages: _stagedImages.isNotEmpty,
      hasAudio: false,
    );
    final privacyPreferences = await ref
        .read(privacyPreferencesServiceProvider)
        .load();
    final conversationId = ref.read(chatNotifierProvider).value?.conversationId;

    if (!mounted) {
      return;
    }

    if (_stagedImages.isNotEmpty &&
        selection.isCloud &&
        privacyPreferences.imageCloudConfirmationEnabled) {
      final confirmed = await showImageCloudPrivacyDialog(
        context: context,
        providerLabel: selection.providerLabel,
        imageCount: _stagedImages.length,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    final review = await ref.read(outboundPrivacyGuardServiceProvider).review(
      conversationId: conversationId,
      originalText: text,
    );

    if (!mounted) {
      return;
    }

    final requiresReview = privacyPreferences.sendBeforeConfirmEnabled ||
        (selection.isCloud && review.hasSensitiveData);

    var outboundText = text;
    if (requiresReview) {
      final decision = await showOutboundPrivacyReviewDialog(
        context: context,
        providerLabel: selection.providerLabel,
        isCloudProvider: selection.isCloud,
        review: review,
      );
      switch (decision) {
        case OutboundPrivacyDecision.cancel:
          return;
        case OutboundPrivacyDecision.sendOriginal:
          outboundText = text;
          break;
        case OutboundPrivacyDecision.sendSanitized:
          outboundText = review.sanitizedText;
          break;
      }
    }

    if (!mounted) {
      return;
    }

    _textController.clear();

    final images = List<PickedImage>.from(_stagedImages);
    setState(() {
      _stagedImages.clear();
    });

    await ref
        .read(chatNotifierProvider.notifier)
        .sendMessage(
          outboundText,
          selection.gateway,
          images: images,
          audios: const [],
          buildContext: context,
        );
  }

  Future<void> _recordAndSendVoiceMessage() async {
    if (_isRecordingVoice) return;
    final chatState = ref.read(chatNotifierProvider).value;
    if (chatState?.isStreaming == true) return;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能发送语音消息')),
      );
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}${Platform.pathSeparator}voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final startedAt = DateTime.now();
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
      ),
      path: path,
    );

    if (!mounted) {
      await _audioRecorder.stop();
      return;
    }

    setState(() {
      _isRecordingVoice = true;
    });

    final shouldSend =
        await showModalBottomSheet<bool>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '正在录音',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('点击“发送”结束录音并发送语音消息。'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          icon: const Icon(Icons.send),
                          label: const Text('发送'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;

    final recordedPath = await _audioRecorder.stop();

    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
      });
    }

    if (!shouldSend || recordedPath == null || recordedPath.trim().isEmpty) {
      if (recordedPath != null) {
        final abandoned = File(recordedPath);
        if (await abandoned.exists()) {
          await abandoned.delete();
        }
      }
      return;
    }

    final audioFile = File(recordedPath);
    if (!await audioFile.exists()) {
      return;
    }

    final sizeBytes = await audioFile.length();
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;

    final resolver = ref.read(chatGatewayResolverProvider);
    final selection = await resolver.resolveSelectionForInput(
      userContent: '[语音消息]',
      hasImages: false,
      hasAudio: true,
    );

    await ref.read(chatNotifierProvider.notifier).sendMessage(
      '',
      selection.gateway,
      images: const [],
      audios: [
        PickedAudio(
          filePath: recordedPath,
          mimeType: 'audio/m4a',
          sizeBytes: sizeBytes,
          durationMs: durationMs,
        ),
      ],
      buildContext: context,
    );
  }

  Future<void> _pickImage(ImageInputSource source) async {
    final service = ref.read(imageInputServiceProvider);
    PickedImage? image;
    if (source == ImageInputSource.camera) {
      image = await service.pickFromCamera();
    } else if (source == ImageInputSource.gallery) {
      image = await service.pickFromGallery();
    }
    if (image != null) {
      setState(() {
        _stagedImages.add(image!);
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageInputSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('相册'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageInputSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('文件（PDF / Word / Excel / TXT / CSV / Markdown）'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    final service = ref.read(fileInputServiceProvider);
    final resolver = ref.read(chatGatewayResolverProvider);
    LlmGateway? gateway;
    try {
      gateway = await resolver.resolve();
    } catch (_) {
      gateway = null;
    }
    PickedDocument? doc;
    try {
      doc = await service.pickAndIndex(gateway);
    } on FileTooLargeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件过大：$e')),
      );
      return;
    }
    if (doc == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '「${doc.name}」已导入，共索引 ${doc.indexedChunkCount} 个片段',
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _stagedImages.removeAt(index);
    });
  }

  Future<void> _startNewConversation() async {
    _textController.clear();
    setState(() {
      _stagedImages.clear();
    });
    await ref.read(chatNotifierProvider.notifier).startNewConversation();
  }

  Future<void> _renameConversationTitle() async {
    final currentState = ref.read(chatNotifierProvider).value;
    if (currentState == null) return;

    final controller = TextEditingController(
      text: currentState.conversationTitle ?? '',
    );

    final nextTitle = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('重命名会话'),
          content: TextField(
            key: const Key('rename_dialog_text_field'),
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(
              hintText: '输入会话标题',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || nextTitle == null) return;
    await ref.read(chatNotifierProvider.notifier).renameConversationTitle(nextTitle);
  }

  String _resolveAppBarTitle(ChatState? state) {
    final title = state?.conversationTitle?.trim();
    if (title == null || title.isEmpty) {
      return '新对话';
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagServiceProvider);
    if (!flags.isEnabled(AppFeatureModule.multimodalChat)) {
      return const FeatureDisabledView(
        title: '多模态对话已关闭',
        message: '请在 Feature Flag 中启用 multimodalChat 模块。',
      );
    }

    final chatAsync = ref.watch(chatNotifierProvider);

    // Show error via SnackBar
    ref.listen<AsyncValue<ChatState>>(chatNotifierProvider, (_, next) {
      final error = next.value?.error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            action: SnackBarAction(
              label: '关闭',
              onPressed: () {
                ref.read(chatNotifierProvider.notifier).clearError();
              },
            ),
          ),
        );
        ref.read(chatNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_resolveAppBarTitle(chatAsync.value)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '重命名会话标题',
            onPressed: _renameConversationTitle,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建会话',
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '查看对话历史',
            onPressed: () => context.push('/chat/history'),
          ),
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (state) => DropTarget(
          onDragDone: (detail) async {
            final service = ref.read(imageInputServiceProvider);
            for (final file in detail.files) {
              final result = await service.processDragAndDrop(file.path);
              if (result != null) {
                setState(() {
                  _stagedImages.add(result);
                });
              }
            }
          },
          child: Column(
            children: [
              Expanded(
                child: state.messages.isEmpty
                    ? const Center(
                        key: ValueKey('chat_empty_state'),
                        child: Text(
                          '发送消息开始对话',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('chat_message_list'),
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg =
                              state.messages[state.messages.length - 1 - index];
                          return _MessageBubble(message: msg);
                        },
                      ),
              ),
              if (state.isStreaming)
                const LinearProgressIndicator(minHeight: 2),
              Consumer(
                builder: (context, ref, _) {
                  final status =
                      ref.watch(toolCallStatusProvider);
                  if (status == null) return const SizedBox.shrink();
                  return _ToolCallStatusBar(message: status);
                },
              ),
              if (_stagedImages.isNotEmpty)
                _StagedImagesRow(images: _stagedImages, onRemove: _removeImage),
              _InputRow(
                controller: _textController,
                isStreaming: state.isStreaming,
                hasStagedImages: _stagedImages.isNotEmpty,
                isRecordingVoice: _isRecordingVoice,
                onSend: _sendMessage,
                onMicInput: _recordAndSendVoiceMessage,
                onStartCall: () => context.push('/chat/voice'),
                onAttach: _showAttachmentOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});

  final DisplayMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Context compression summary — render as a separator, not a bubble.
    if (message.isSummaryMarker) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Expanded(child: Divider(color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '上下文已压缩',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            const Expanded(child: Divider(color: Colors.grey)),
          ],
        ),
      );
    }

    final isUser = message.role == ChatRole.user;
    final isAssistant = message.role == ChatRole.assistant;
    final theme = Theme.of(context);
    final generativeUiEnabled = ref
        .watch(featureFlagServiceProvider)
        .isEnabled(AppFeatureModule.generativeUi);

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasImages) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.attachments
                  .where((a) => a.type == 'image')
                  .map(
                    (a) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(a.filePath),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
          ],
          if (message.attachments.any((a) => a.type == 'audio')) ...[
            ...message.attachments
                .where((a) => a.type == 'audio')
                .map(
                  (a) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '语音消息 · ${p.basename(a.filePath)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
          isUser
              ? Text(
                  message.content,
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                )
              : generativeUiEnabled
                  ? GenerativeUiMessageContent(content: message.content)
                  : MarkdownMessageContent(content: message.content),
        ],
      ),
    );

    // Wrap assistant messages with long-press context menu and branch switcher
    if (isAssistant) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _showRegenerateMenu(context, ref),
              child: bubble,
            ),
            if (message.hasBranches)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: BranchSwitcher(
                  currentIndex: message.activeSiblingIndex,
                  totalBranches: message.siblingIds.length,
                  onPrevious: () {
                    ref
                        .read(chatNotifierProvider.notifier)
                        .switchBranch(
                          message.parentMessageId!,
                          message.activeSiblingIndex - 1,
                        );
                  },
                  onNext: () {
                    ref
                        .read(chatNotifierProvider.notifier)
                        .switchBranch(
                          message.parentMessageId!,
                          message.activeSiblingIndex + 1,
                        );
                  },
                ),
              ),
          ],
        ),
      );
    }

    return Align(alignment: Alignment.centerRight, child: bubble);
  }

  void _showRegenerateMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final gateway = await ref
                      .read(chatGatewayResolverProvider)
                      .resolve();
                  await notifier.regenerateMessage(message.id, gateway);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.isStreaming,
    required this.hasStagedImages,
    required this.isRecordingVoice,
    required this.onSend,
    required this.onMicInput,
    required this.onStartCall,
    this.onAttach,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final bool hasStagedImages;
  final bool isRecordingVoice;
  final VoidCallback onSend;
  final Future<void> Function() onMicInput;
  final VoidCallback onStartCall;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              tooltip: '展开多模态工具',
              onPressed: isStreaming ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                key: const ValueKey('chat_input'),
                controller: controller,
                enabled: !isStreaming,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isRecordingVoice ? Icons.fiber_manual_record : Icons.mic_outlined,
              ),
              tooltip: '语音输入',
              onPressed: isStreaming || isRecordingVoice ? null : onMicInput,
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                final canSend =
                    !isStreaming &&
                    (hasText || hasStagedImages);
                final showSend = hasText;
                return IconButton.filled(
                  key: const ValueKey('chat_send_button'),
                  icon: Icon(showSend ? Icons.send : Icons.call),
                  tooltip: showSend ? '发送消息' : '音频全双工对话',
                  onPressed: showSend
                      ? (canSend ? onSend : null)
                      : (isStreaming ? null : onStartCall),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StagedImagesRow extends StatelessWidget {
  const _StagedImagesRow({required this.images, required this.onRemove});

  final List<PickedImage> images;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final img = images[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(img.filePath),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Semantics(
                      label: '移除已选择图片',
                      button: true,
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ToolCallStatusBar extends StatelessWidget {
  const _ToolCallStatusBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
