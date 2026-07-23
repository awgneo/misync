import '../../storage/blob.dart';

class PushedBlob extends Blob<List<int>> {
  static final PushedBlob _instance = PushedBlob._();
  static PushedBlob get instance => _instance;

  PushedBlob._()
      : super(
          module: 'notifications',
          name: 'pushed',
          defaultValue: const [],
        );

  static List<int> get ids => _instance.value;

  static void add(int id) {
    final updated = List<int>.from(_instance.value);
    if (!updated.contains(id)) {
      updated.add(id);
      if (updated.length > 100) {
        updated.removeAt(0);
      }
      _instance.update(updated);
    }
  }

  static void remove(int id) {
    final updated = List<int>.from(_instance.value);
    if (updated.remove(id)) {
      _instance.update(updated);
    }
  }

  static void setAll(Iterable<int> newIds) {
    final updated = newIds.take(100).toList();
    _instance.update(updated);
  }

  @override
  List<int> parse(dynamic json) {
    if (json is List) {
      return json.map((e) => (e as num).toInt()).toList();
    }
    return const [];
  }

  @override
  dynamic serialize(List<int> value) => value;
}
