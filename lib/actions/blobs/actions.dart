import '../../storage/blob.dart';

class ActionsBlob extends Blob<List<Map<String, String>>> {
  static final ActionsBlob _instance = ActionsBlob._();
  static ActionsBlob get instance => _instance;

  ActionsBlob._()
      : super(
          module: 'actions',
          name: 'settings',
          defaultValue: const [
            {
              'id': '1',
              'name': 'Mute Phone',
              'intent': 'com.llamalab.automate.intent.action.START_FLOW',
              'package': 'com.llamalab.automate',
            },
            {
              'id': '2',
              'name': 'Find My Car',
              'intent': 'net.dinglisch.android.taskerm.ACTION_TASK',
              'package': 'net.dinglisch.android.taskerm',
            },
          ],
        );

  static List<Map<String, String>> get list => _instance.value;

  static void ensureMessageReplyAction() {
    final list = List<Map<String, String>>.from(_instance.value);
    final exists = list.any((a) => a['id'] == 'msg_reply');
    if (!exists) {
      list.add({
        'id': 'msg_reply',
        'name': 'Incoming Message Reply',
        'intent': 'com.misync.action.MESSAGE_REPLY',
        'package': 'com.misync',
      });
      _instance.write(list);
    }
  }

  @override
  List<Map<String, String>> parse(dynamic json) {
    final raw = json as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((item) => Map<String, String>.from(item as Map)).toList();
  }

  @override
  dynamic serialize(List<Map<String, String>> value) => value;
}
