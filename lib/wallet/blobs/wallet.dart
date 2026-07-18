import '../../storage/blob.dart';

class Wallet {
  final bool enabled;
  final int retentionDays;

  Wallet({required this.enabled, required this.retentionDays});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      enabled: json['enabled'] ?? false,
      retentionDays: json['retentionDays'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'retentionDays': retentionDays};
  }
}

class WalletBlob extends Blob<Wallet> {
  WalletBlob()
    : super(
        module: 'wallet',
        name: 'wallet',
        defaultValue: Wallet(enabled: false, retentionDays: 30),
      );

  static final WalletBlob instance = WalletBlob();

  @override
  Wallet parse(dynamic json) => Wallet.fromJson(Map<String, dynamic>.from(json));

  @override
  dynamic serialize(Wallet value) => value.toJson();
}
