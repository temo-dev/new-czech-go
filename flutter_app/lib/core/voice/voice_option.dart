class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.name,
    required this.gender,
    required this.provider,
  });

  final String id;
  final String name;
  final String gender;   // "female" | "male"
  final String provider; // "aws_polly" | "elevenlabs"

  factory VoiceOption.fromJson(Map<String, dynamic> json) => VoiceOption(
        id: json['id'] as String,
        name: json['name'] as String,
        gender: json['gender'] as String,
        provider: json['provider'] as String,
      );

  @override
  bool operator ==(Object other) => other is VoiceOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
