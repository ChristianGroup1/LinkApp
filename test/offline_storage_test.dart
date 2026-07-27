import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:link/data/offline/offline_cache.dart';
import 'package:link/data/offline/offline_write_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('concurrent queue writes preserve every offline operation', () async {
    final queues = List.generate(4, (_) => OfflineWriteQueue());

    await Future.wait(
      List.generate(100, (index) {
        return queues[index % queues.length].enqueue(
          QueuedOperation(
            id: 'operation-$index',
            type: OfflineOpType.memberUpdate,
            payload: {'id': 'member-$index'},
            queuedAt: DateTime.utc(2026, 1, 1),
          ),
        );
      }),
    );

    final operations = await OfflineWriteQueue().all();
    expect(operations, hasLength(100));
    expect(operations.map((item) => item.id).toSet(), hasLength(100));
  });

  test('concurrent id mappings preserve every remapping', () async {
    final queue = OfflineWriteQueue();

    await Future.wait(
      List.generate(
        100,
        (index) => queue.mapId('offline-$index', 'server-$index'),
      ),
    );

    final mappings = await queue.idMappings();
    expect(mappings, hasLength(100));
    expect(await queue.resolveId('offline-42'), 'server-42');
  });

  test(
    'pendingDeletedEntityIds returns ids from queued delete operations',
    () async {
      final queue = OfflineWriteQueue();
      await queue.enqueue(
        QueuedOperation(
          id: 'delete-member',
          type: OfflineOpType.memberDelete,
          payload: {'id': 'member-1'},
          queuedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'delete-meeting',
          type: OfflineOpType.meetingDelete,
          payload: {'id': 'meeting-9'},
          queuedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'update-member',
          type: OfflineOpType.memberUpdate,
          payload: {'id': 'member-2'},
          queuedAt: DateTime.utc(2026, 1, 3),
        ),
      );

      final pendingDeletes = await queue.pendingDeletedEntityIds();
      expect(pendingDeletes, {'member-1', 'meeting-9'});
    },
  );

  test(
    'corrupt cached JSON is discarded instead of crashing offline reads',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_cache_members_church-1': '{incomplete-json',
      });

      final cache = OfflineCache();
      expect(await cache.readMembers('church-1'), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offline_cache_members_church-1'), isFalse);
    },
  );
}
