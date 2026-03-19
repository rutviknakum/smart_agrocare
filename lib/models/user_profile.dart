class UserProfile {
  final String name;
  final String language; // 'en', 'hi', 'gu'
  final String village;
  final String taluka;
  final String district;

  const UserProfile({
    required this.name,
    required this.language,
    required this.village,
    required this.taluka,
    required this.district,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language,
    'village': village,
    'taluka': taluka,
    'district': district,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    language: json['language'] ?? 'en',
    village: json['village'] ?? '',
    taluka: json['taluka'] ?? '',
    district: json['district'] ?? '',
  );
}
