import '../../storage/blob.dart';

class SyncState {
  final int syncIntervalMinutes; // Sync frequency: e.g. 0 (disabled), 5, 10, 15, 30, 60

  const SyncState({
    required this.syncIntervalMinutes,
  });

  SyncState copyWith({
    int? syncIntervalMinutes,
  }) {
    return SyncState(
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    );
  }
}

class SyncBlob extends Blob<SyncState> {
  static final SyncBlob _instance = SyncBlob._();
  static SyncBlob get instance => _instance;

  SyncBlob._()
    : super(
        module: 'device',
        name: 'sync',
        defaultValue: const SyncState(
          syncIntervalMinutes: 15,
        ),
      );

  static int get syncIntervalMinutes => _instance.value.syncIntervalMinutes;

  @override
  SyncState parse(dynamic json) {
    final map = Map<String, dynamic>.from(json ?? {});
    return SyncState(
      syncIntervalMinutes: map['syncIntervalMinutes'] ?? 15,
    );
  }

  @override
  dynamic serialize(SyncState value) => {
    'syncIntervalMinutes': value.syncIntervalMinutes,
  };
}
