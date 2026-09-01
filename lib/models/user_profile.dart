class UserProfile {
  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String timezone;
  final String familyCode;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.timezone,
    required this.familyCode,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      timezone: (map['timezone'] as String?) ?? 'Africa/Casablanca',
      familyCode: (map['family_code'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'timezone': timezone,
      };

  UserProfile copyWith({String? fullName, String? phone, String? avatarUrl, String? timezone}) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timezone: timezone ?? this.timezone,
      familyCode: familyCode,
      createdAt: createdAt,
    );
  }
}
