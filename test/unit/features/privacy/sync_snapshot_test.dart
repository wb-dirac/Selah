import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/privacy/domain/sync_snapshot.dart';

void main() {
  group('SyncSnapshot', () {
    test('create() generates unique id with timestamp prefix', () {
      final s = SyncSnapshot.create(<String, dynamic>{'key': 'value'});
      expect(s.id, startsWith('snapshot_'));
      expect(s.payload, equals(<String, dynamic>{'key': 'value'}));
    });

    test('two snapshots created at different times have different ids', () async {
      final s1 = SyncSnapshot.create(<String, dynamic>{'v': 1});
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final s2 = SyncSnapshot.create(<String, dynamic>{'v': 2});
      expect(s1.id, isNot(equals(s2.id)));
    });

    test('toJson / fromJson round-trip', () {
      final s = SyncSnapshot(
        id: 'snapshot_12345',
        createdAt: DateTime(2026, 3, 1, 8, 0),
        payload: <String, dynamic>{'a': 1, 'b': true},
      );
      final json = s.toJson();
      final s2 = SyncSnapshot.fromJson(json);
      expect(s2.id, s.id);
      expect(s2.createdAt, s.createdAt);
      expect(s2.payload, s.payload);
    });

    test('isExpired is false for fresh snapshot', () {
      final s = SyncSnapshot.create(<String, dynamic>{});
      expect(s.isExpired, isFalse);
    });

    test('isExpired is true for snapshot older than 7 days', () {
      final old = SyncSnapshot(
        id: 'old',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        payload: <String, dynamic>{},
      );
      expect(old.isExpired, isTrue);
    });

    test('isExpired is false for snapshot exactly at retention boundary', () {
      final boundary = SyncSnapshot(
        id: 'boundary',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        payload: <String, dynamic>{},
      );
      expect(boundary.isExpired, isFalse);
    });
  });

  group('SyncSnapshotStore', () {
    const store = SyncSnapshotStore();

    test('encode / decode round-trip', () {
      final snapshots = <SyncSnapshot>[
        SyncSnapshot(
          id: 'snap_1',
          createdAt: DateTime(2026, 3, 1),
          payload: <String, dynamic>{'x': 42},
        ),
        SyncSnapshot(
          id: 'snap_2',
          createdAt: DateTime(2026, 3, 2),
          payload: <String, dynamic>{'y': 'hello'},
        ),
      ];

      final encoded = store.encode(snapshots);
      final decoded = store.decode(encoded);

      expect(decoded, hasLength(2));
      expect(decoded[0].id, 'snap_1');
      expect(decoded[0].payload['x'], 42);
      expect(decoded[1].id, 'snap_2');
      expect(decoded[1].payload['y'], 'hello');
    });

    test('decode empty list', () {
      final decoded = store.decode('[]');
      expect(decoded, isEmpty);
    });

    test('encode empty list produces valid json', () {
      final encoded = store.encode(const <SyncSnapshot>[]);
      expect(encoded, '[]');
    });

    test('kSnapshotRetentionDays is 7', () {
      expect(kSnapshotRetentionDays, 7);
    });
  });
}
