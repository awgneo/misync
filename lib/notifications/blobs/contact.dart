import '../../storage/blob.dart';

class Contact {
  final bool callEnabled;
  final bool textEnabled;
  final bool emailEnabled;

  Contact({
    this.callEnabled = true,
    this.textEnabled = true,
    this.emailEnabled = true,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      callEnabled: json['callEnabled'] ?? true,
      textEnabled: json['textEnabled'] ?? true,
      emailEnabled: json['emailEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callEnabled': callEnabled,
      'textEnabled': textEnabled,
      'emailEnabled': emailEnabled,
    };
  }
}

class ContactBlob extends Blob<Contact> {
  static final ContactBlob _instance = ContactBlob._();
  static ContactBlob get instance => _instance;

  ContactBlob._()
      : super(
          module: 'notifications',
          name: 'contact',
          defaultValue: Contact(),
        );

  static Contact get contact => _instance.value;
  static set contact(Contact value) {
    _instance.update(value);
  }

  @override
  Contact parse(dynamic json) {
    if (json is Map<String, dynamic>) {
      return Contact.fromJson(Map<String, dynamic>.from(json));
    }
    if (json is bool) {
      return Contact(
        callEnabled: json,
        textEnabled: json,
        emailEnabled: json,
      );
    }
    return Contact();
  }

  @override
  dynamic serialize(Contact value) => value.toJson();
}
