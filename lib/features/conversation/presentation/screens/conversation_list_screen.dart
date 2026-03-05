import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/conversation_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:personal_ai_assistant/features/conversation/domain/conversation_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
	const ConversationListScreen({super.key});

	@override
	ConsumerState<ConversationListScreen> createState() =>
			_ConversationListScreenState();
}

class _ConversationListScreenState
		extends ConsumerState<ConversationListScreen> {
	final _searchController = TextEditingController();
	final _scrollController = ScrollController();

	List<ConversationEntity> _conversations = [];
	bool _isLoading = true;
	bool _isLoadingMore = false;
	int _page = 0;
	bool _hasMore = true;
	String _searchQuery = '';

	static const _pageSize = 20;

	@override
	void initState() {
		super.initState();
		_loadConversations();
		_scrollController.addListener(_onScroll);
		_searchController.addListener(_onSearchChanged);
	}

	@override
	void dispose() {
		_searchController.dispose();
		_scrollController.dispose();
		super.dispose();
	}

	void _onScroll() {
		if (_scrollController.position.pixels >=
				_scrollController.position.maxScrollExtent - 200) {
			_loadMore();
		}
	}

	void _onSearchChanged() {
		final query = _searchController.text.trim();
		if (query != _searchQuery) {
			_searchQuery = query;
			_page = 0;
			_hasMore = true;
			_conversations = [];
			_loadConversations();
		}
	}

	Future<void> _loadConversations() async {
		setState(() => _isLoading = true);
		try {
			final service = ref.read(conversationServiceProvider);
			final results = _searchQuery.isEmpty
					? await service.listConversations(page: 0, pageSize: _pageSize)
					: await service.searchConversations(
							_searchQuery,
							page: 0,
							pageSize: _pageSize,
						);
			if (mounted) {
				setState(() {
					_conversations = results;
					_page = 0;
					_hasMore = results.length >= _pageSize;
					_isLoading = false;
				});
			}
		} catch (e) {
			if (mounted) setState(() => _isLoading = false);
			rethrow;
		}
	}

	Future<void> _loadMore() async {
		if (_isLoadingMore || !_hasMore) return;
		setState(() => _isLoadingMore = true);
		try {
			final service = ref.read(conversationServiceProvider);
			final nextPage = _page + 1;
			final results = _searchQuery.isEmpty
					? await service.listConversations(
							page: nextPage,
							pageSize: _pageSize,
						)
					: await service.searchConversations(
							_searchQuery,
							page: nextPage,
							pageSize: _pageSize,
						);
			if (mounted) {
				setState(() {
					_conversations = [..._conversations, ...results];
					_page = nextPage;
					_hasMore = results.length >= _pageSize;
					_isLoadingMore = false;
				});
			}
		} catch (e) {
			if (mounted) setState(() => _isLoadingMore = false);
			rethrow;
		}
	}

	Future<void> _deleteConversation(ConversationEntity conv) async {
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('删除对话'),
				content: const Text('确定要删除这条对话记录吗？'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(false),
						child: const Text('取消'),
					),
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(true),
						child:
								const Text('删除', style: TextStyle(color: Colors.red)),
					),
				],
			),
		);
		if (confirmed == true) {
			final dao = ref.read(conversationDaoProvider);
			await dao.softDelete(conv.id);
			if (mounted) {
				setState(() {
					_conversations.removeWhere((c) => c.id == conv.id);
				});
			}
		}
	}

	Future<void> _openConversation(ConversationEntity conv) async {
		await ref.read(chatNotifierProvider.notifier).loadConversation(conv.id);
		if (mounted) {
			context.pop();
		}
	}

	Future<void> _createConversation() async {
		await ref.read(chatNotifierProvider.notifier).startNewConversation();
		if (mounted) {
			context.pop();
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('对话历史'),
				actions: [
					IconButton(
						onPressed: _createConversation,
						icon: const Icon(Icons.add),
						tooltip: '新建会话',
					),
				],
			),
			body: Column(
				children: [
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
						child: TextField(
							controller: _searchController,
							decoration: const InputDecoration(
								hintText: '搜索消息内容、工具调用记录...',
								prefixIcon: Icon(Icons.search),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.all(Radius.circular(24)),
								),
								contentPadding: EdgeInsets.symmetric(vertical: 0),
							),
						),
					),
					Expanded(child: _buildBody()),
				],
			),
		);
	}

	Widget _buildBody() {
		if (_isLoading) {
			return const Center(child: CircularProgressIndicator());
		}

		if (_conversations.isEmpty) {
			return const Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
						SizedBox(height: 12),
						Text('暂无对话记录', style: TextStyle(color: Colors.grey)),
					],
				),
			);
		}

		return ListView.builder(
			controller: _scrollController,
			itemCount: _conversations.length + (_isLoadingMore ? 1 : 0),
			itemBuilder: (context, index) {
				if (index == _conversations.length) {
					return const Padding(
						padding: EdgeInsets.all(16),
						child: Center(child: CircularProgressIndicator()),
					);
				}
				final conv = _conversations[index];
				return Dismissible(
					key: Key(conv.id),
					direction: DismissDirection.endToStart,
					background: Container(
						color: Colors.red,
						alignment: Alignment.centerRight,
						padding: const EdgeInsets.symmetric(horizontal: 20),
						child: const Icon(Icons.delete, color: Colors.white),
					),
					confirmDismiss: (_) async {
						// We handle removal manually after the confirmation dialog
						// to give the user a chance to cancel before the item is removed.
						await _deleteConversation(conv);
						return false;
					},
					child: SizedBox(
						height: 68,
						child: ListTile(
							title: Text(conv.title ?? '未命名对话'),
							subtitle: Text(
								_formatDate(conv.updatedAt),
								style: const TextStyle(fontSize: 12, color: Colors.grey),
							),
							onTap: () => _openConversation(conv),
						),
					),
				);
			},
		);
	}

	String _formatDate(DateTime dt) {
		final now = DateTime.now();
		final diff = now.difference(dt);
		if (diff.inDays == 0) {
			return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
		} else if (diff.inDays == 1) {
			return '昨天';
		} else {
			return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
		}
	}
}
