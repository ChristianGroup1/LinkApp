import 'package:flutter_test/flutter_test.dart';
import 'package:link/shared/data/app_data_changes.dart';

void main() {
  test('broadcasts the changed data areas to active listeners', () async {
    final nextChange = AppDataChanges.instance.stream.first;

    AppDataChanges.instance.notify({
      AppDataArea.members,
      AppDataArea.attendance,
    });

    final change = await nextChange;
    expect(change.affectsAny({AppDataArea.members}), isTrue);
    expect(change.affectsAny({AppDataArea.meetings}), isFalse);
  });
}
