import 'dart:async';

enum AppDataArea {
  profile,
  church,
  meetings,
  classes,
  members,
  assignments,
  attendance,
  followUps,
  invitations,
}

class AppDataChange {
  final Set<AppDataArea> areas;

  const AppDataChange(this.areas);

  bool affectsAny(Set<AppDataArea> targets) => areas.any(targets.contains);
}

/// A lightweight in-app invalidation bus for keeping cached tabs in sync.
class AppDataChanges {
  AppDataChanges._();

  static final AppDataChanges instance = AppDataChanges._();

  final StreamController<AppDataChange> _controller =
      StreamController<AppDataChange>.broadcast(sync: true);

  Stream<AppDataChange> get stream => _controller.stream;

  void notify(Set<AppDataArea> areas) {
    if (areas.isEmpty) return;
    _controller.add(AppDataChange(Set.unmodifiable(areas)));
  }
}
