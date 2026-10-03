import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/offline/offline_write_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  QueuedOperation change(String id, bool previous, bool locked) =>
      QueuedOperation(
        id: id,
        type: OfflineOpType.sessionLockState,
        payload: {
          'id': 'session-1',
          'previous_is_locked': previous,
          'previous_session': {'id': 'session-1', 'is_locked': previous},
          'is_locked': locked,
        },
        queuedAt: DateTime(2026, 10, 3),
      );

  test('unlock survives completion of an older in-flight lock', () async {
    final queue = OfflineWriteQueue();
    await queue.setAttendanceSessionLock(change('lock', false, true));
    final inFlight = (await queue.all()).single;
    await queue.setAttendanceSessionLock(change('unlock', true, false));
    await queue.remove(inFlight.id);
    final remaining = (await queue.all()).single;
    expect(remaining.id, 'unlock');
    expect(remaining.payload['is_locked'], false);
  });

  test('latest lock choice persists across queue instances', () async {
    final queue = OfflineWriteQueue();
    await queue.setAttendanceSessionLock(change('unlock', true, false));
    await queue.setAttendanceSessionLock(change('lock', false, true));
    final remaining = (await OfflineWriteQueue().all()).single;
    expect(remaining.id, 'lock');
    expect(remaining.payload['is_locked'], true);
    expect(remaining.payload['previous_is_locked'], true);
  });
}
