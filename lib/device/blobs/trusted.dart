import '../../storage/blob.dart';

class TrustedState {
  final List<Map<String, String>> contacts;
  final bool enabled;

  const TrustedState({
    required this.contacts,
    required this.enabled,
  });

  TrustedState copyWith({
    List<Map<String, String>>? contacts,
    bool? enabled,
  }) {
    return TrustedState(
      contacts: contacts ?? this.contacts,
      enabled: enabled ?? this.enabled,
    );
  }
}

class TrustedBlob extends Blob<TrustedState> {
  static final TrustedBlob _instance = TrustedBlob._();
  static TrustedBlob get instance => _instance;

  TrustedBlob._()
    : super(
        module: 'device',
        name: 'trusted',
        defaultValue: const TrustedState(
          contacts: [],
          enabled: true,
        ),
      );

  static List<Map<String, String>> get contacts => _instance.value.contacts;
  static bool get enabled => _instance.value.enabled;

  @override
  TrustedState parse(dynamic json) {
    final map = Map<String, dynamic>.from(json ?? {});
    final rawContacts = map['contacts'] as List?;
    List<Map<String, String>> contactsList = [];
    if (rawContacts != null) {
      contactsList = rawContacts
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    }
    return TrustedState(
      contacts: contactsList,
      enabled: map['enabled'] ?? true,
    );
  }

  @override
  dynamic serialize(TrustedState value) => {
    'contacts': value.contacts,
    'enabled': value.enabled,
  };
}
