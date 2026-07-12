import '../../storage/blob.dart';

class HealthGoals {
  final int calories;
  final int steps;
  final int standing;
  final int moving;

  const HealthGoals({
    this.calories = 300,
    this.steps = 10000,
    this.standing = 12,
    this.moving = 30,
  });

  HealthGoals copyWith({
    int? calories,
    int? steps,
    int? standing,
    int? moving,
  }) {
    return HealthGoals(
      calories: calories ?? this.calories,
      steps: steps ?? this.steps,
      standing: standing ?? this.standing,
      moving: moving ?? this.moving,
    );
  }

  factory HealthGoals.fromJson(Map<String, dynamic> json) {
    return HealthGoals(
      calories: json['calories'] as int? ?? 300,
      steps: json['steps'] as int? ?? 10000,
      standing: json['standing'] as int? ?? 12,
      moving: json['moving'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'steps': steps,
      'standing': standing,
      'moving': moving,
    };
  }
}

class Health {
  final bool enabled;
  final String birthday;
  final int gender;
  final double height;
  final double weight;
  final bool imperial;
  final HealthGoals goals;

  const Health({
    this.enabled = false,
    this.birthday = '19950101',
    this.gender = 1,
    this.height = 0.0,
    this.weight = 0.0,
    this.imperial = false,
    this.goals = const HealthGoals(),
  });

  Health copyWith({
    bool? enabled,
    String? birthday,
    int? gender,
    double? height,
    double? weight,
    bool? imperial,
    HealthGoals? goals,
  }) {
    return Health(
      enabled: enabled ?? this.enabled,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      imperial: imperial ?? this.imperial,
      goals: goals ?? this.goals,
    );
  }

  factory Health.fromJson(Map<String, dynamic> json) {
    return Health(
      enabled: json['enabled'] as bool? ?? false,
      birthday: json['birthday'] as String? ?? '19950101',
      gender: json['gender'] as int? ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      imperial: json['imperial'] as bool? ?? false,
      goals: json['goals'] != null
          ? HealthGoals.fromJson(
              Map<String, dynamic>.from(json['goals'] as Map),
            )
          : const HealthGoals(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'birthday': birthday,
      'gender': gender,
      'height': height,
      'weight': weight,
      'imperial': imperial,
      'goals': goals.toJson(),
    };
  }
}

class HealthBlob extends Blob<Health> {
  static final HealthBlob _instance = HealthBlob._();
  static HealthBlob get instance => _instance;

  HealthBlob._()
    : super(module: 'health', name: 'settings', defaultValue: const Health());

  static Health get settings => _instance.value;
  static bool get enabled => _instance.value.enabled;

  @override
  Health parse(dynamic json) {
    if (json == null) return const Health();
    return Health.fromJson(Map<String, dynamic>.from(json as Map));
  }

  @override
  dynamic serialize(Health value) => value.toJson();
}
