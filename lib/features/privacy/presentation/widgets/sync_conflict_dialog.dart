import 'package:flutter/material.dart';

enum SyncConflictChoice { keepLocal, useRemote }

class SyncConflictDialog extends StatelessWidget {
  const SyncConflictDialog({
    super.key,
    required this.localPayload,
    required this.remotePayload,
    required this.localTimestamp,
    required this.remoteTimestamp,
  });

  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final DateTime? localTimestamp;
  final DateTime remoteTimestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffItems = _buildDiffItems();

    return AlertDialog(
      title: const Text('检测到同步冲突'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '本地版本与远端 Gist 版本不一致，请选择保留哪个版本。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _VersionColumn(
                      label: '本地版本',
                      timestamp: localTimestamp,
                      isLocal: true,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VersionColumn(
                      label: '远端版本 (GitHub Gist)',
                      timestamp: remoteTimestamp,
                      isLocal: false,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              if (diffItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text('差异内容', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...diffItems.map(
                  (item) => _DiffRow(item: item, theme: theme),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SyncConflictChoice.keepLocal),
          child: const Text('保留本地'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(SyncConflictChoice.useRemote),
          child: const Text('使用远端版本'),
        ),
      ],
    );
  }

  List<_DiffItem> _buildDiffItems() {
    final items = <_DiffItem>[];

    final localProviders =
        (localPayload['providers'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final remoteProviders =
        (remotePayload['providers'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    if (localProviders.length != remoteProviders.length) {
      items.add(
        _DiffItem(
          label: 'LLM 配置数量',
          localValue: '${localProviders.length} 个',
          remoteValue: '${remoteProviders.length} 个',
        ),
      );
    }

    final localIds = localProviders
        .map((p) => p['provider_id'] as String? ?? '')
        .toSet();
    final remoteIds = remoteProviders
        .map((p) => p['provider_id'] as String? ?? '')
        .toSet();

    final onlyLocal = localIds.difference(remoteIds);
    final onlyRemote = remoteIds.difference(localIds);

    for (final id in onlyLocal) {
      final cfg = localProviders.firstWhere(
        (p) => (p['provider_id'] as String?) == id,
        orElse: () => const {},
      );
      items.add(
        _DiffItem(
          label: '仅本地存在',
          localValue: cfg['display_name'] as String? ?? id,
          remoteValue: '—',
        ),
      );
    }

    for (final id in onlyRemote) {
      final cfg = remoteProviders.firstWhere(
        (p) => (p['provider_id'] as String?) == id,
        orElse: () => const {},
      );
      items.add(
        _DiffItem(
          label: '仅远端存在',
          localValue: '—',
          remoteValue: cfg['display_name'] as String? ?? id,
        ),
      );
    }

    final localSyncItems =
        localPayload['sync_items'] as Map<String, dynamic>? ?? const {};
    final remoteSyncItems =
        remotePayload['sync_items'] as Map<String, dynamic>? ?? const {};

    for (final key in localSyncItems.keys) {
      final localVal = localSyncItems[key];
      final remoteVal = remoteSyncItems[key];
      if (localVal != remoteVal) {
        items.add(
          _DiffItem(
            label: '同步项: $key',
            localValue: localVal?.toString() ?? '—',
            remoteValue: remoteVal?.toString() ?? '—',
          ),
        );
      }
    }

    return items;
  }
}

class _VersionColumn extends StatelessWidget {
  const _VersionColumn({
    required this.label,
    required this.timestamp,
    required this.isLocal,
    required this.theme,
  });

  final String label;
  final DateTime? timestamp;
  final bool isLocal;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final containerColor = isLocal
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.tertiaryContainer;
    final onContainerColor = isLocal
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onTertiaryContainer;
    final formattedTime = timestamp != null
        ? _formatDateTime(timestamp!.toLocal())
        : '尚未同步';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: containerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: onContainerColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onContainerColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

class _DiffItem {
  const _DiffItem({
    required this.label,
    required this.localValue,
    required this.remoteValue,
  });

  final String label;
  final String localValue;
  final String remoteValue;
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.item, required this.theme});

  final _DiffItem item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.localValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.remoteValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<SyncConflictChoice?> showSyncConflictDialog({
  required BuildContext context,
  required Map<String, dynamic> localPayload,
  required Map<String, dynamic> remotePayload,
  required DateTime? localTimestamp,
  required DateTime remoteTimestamp,
}) async {
  return showDialog<SyncConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => SyncConflictDialog(
      localPayload: localPayload,
      remotePayload: remotePayload,
      localTimestamp: localTimestamp,
      remoteTimestamp: remoteTimestamp,
    ),
  );
}
