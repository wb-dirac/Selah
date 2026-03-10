import 'dart:convert';

const int kSnapshotRetentionDays = 7;

class SyncSnapshot {
  const SyncSnapshot({
    required this.id,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  bool get isExpired {
    final cutoff = DateTime.now().subtract(
      const Duration(days: kSnapshotRetentionDays),
    );
    return createdAt.isBefore(cutoff);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'payload': payload,
      };

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    return SyncSnapshot(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  static SyncSnapshot create(Map<String, dynamic> payload) {
    final now = DateTime.now();
    return SyncSnapshot(
      id: 'snapshot_${now.millisecondsSinceEpoch}',
      createdAt: now,
      payload: payload,
    );
  }
}

class SyncSnapshotStore {
  const SyncSnapshotStore();

  List<SyncSnapshot> decode(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(SyncSnapshot.fromJson)
        .toList();
  }

  String encode(List<SyncSnapshot> snapshots) {
    return jsonEncode(snapshots.map((s) => s.toJson()).toList());
  }
}
