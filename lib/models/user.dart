class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int avatarIndex;
  final String? profilePicture; // Custom uploaded profile photo via Cloudinary
  final bool isMfaEnabled;
  final bool isTotpEnabled; // Support for Authenticator app 2FA
  final String? totpSecret;  // Google Authenticator secret key
  final String? mfaPhoneNumber;
  final List<String> wishlistedProductIds;
  final String role; // 'user' or 'admin'
  final List<UserAddress> addresses;
  final List<UserNotification> notifications;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarIndex = 0,
    this.profilePicture,
    this.isMfaEnabled = false,
    this.isTotpEnabled = false,
    this.totpSecret,
    this.mfaPhoneNumber,
    List<String>? wishlistedProductIds,
    this.role = 'user',
    List<UserAddress>? addresses,
    List<UserNotification>? notifications,
  }) : this.wishlistedProductIds = wishlistedProductIds ?? const [],
       this.addresses = addresses ?? const [],
       this.notifications = notifications ?? const [];

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    int? avatarIndex,
    String? profilePicture,
    bool? isMfaEnabled,
    bool? isTotpEnabled,
    String? totpSecret,
    String? mfaPhoneNumber,
    List<String>? wishlistedProductIds,
    String? role,
    List<UserAddress>? addresses,
    List<UserNotification>? notifications,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      profilePicture: profilePicture ?? this.profilePicture,
      isMfaEnabled: isMfaEnabled ?? this.isMfaEnabled,
      isTotpEnabled: isTotpEnabled ?? this.isTotpEnabled,
      totpSecret: totpSecret ?? this.totpSecret,
      mfaPhoneNumber: mfaPhoneNumber ?? this.mfaPhoneNumber,
      wishlistedProductIds: wishlistedProductIds ?? this.wishlistedProductIds,
      role: role ?? this.role,
      addresses: addresses ?? this.addresses,
      notifications: notifications ?? this.notifications,
    );
  }

  // Predefined avatar selections with premium asset keys/indexes (emojis replaced by labels)
  static const List<String> avatars = [
    'Newborn',
    'Baby Panda',
    'Teddy Bear',
    'Baby Unicorn',
    'Tiger Cub',
    'Baby Owl',
  ];
}

class UserAddress {
  final String id;
  final String title;
  final String recipientName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String postalCode;
  final bool isDefault;

  UserAddress({
    required this.id,
    required this.title,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.postalCode,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'recipientName': recipientName,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'postalCode': postalCode,
      'isDefault': isDefault,
    };
  }

  factory UserAddress.fromMap(String id, Map<String, dynamic> map) {
    return UserAddress(
      id: id,
      title: map['title'] ?? '',
      recipientName: map['recipientName'] ?? '',
      phone: map['phone'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'],
      city: map['city'] ?? '',
      postalCode: map['postalCode'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }
}

class UserNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'order' | 'support'
  final bool read;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'createdAt': createdAt,
    };
  }

  factory UserNotification.fromMap(String id, Map<String, dynamic> map) {
    return UserNotification(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'order',
      read: map['read'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }
}
