/// A temporary, single-use code a patient generates to invite a caregiver.
/// Purely client-side display state — never persisted locally, since it's
/// only useful for the few minutes it's valid.
class FamilyLinkCode {
  final String code;
  final DateTime expiresAt;

  const FamilyLinkCode({required this.code, required this.expiresAt});

  factory FamilyLinkCode.fromMap(Map<String, dynamic> map) {
    return FamilyLinkCode(
      code: map['code'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String).toLocal(),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remaining => expiresAt.difference(DateTime.now());
}
