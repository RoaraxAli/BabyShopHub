class VoucherModel {
  final String id;
  final String code;
  final String type; // 'percentage' or 'flat'
  final double value;
  final double minPurchase;

  VoucherModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.minPurchase,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': type,
      'value': value,
      'minPurchase': minPurchase,
    };
  }

  factory VoucherModel.fromMap(Map<String, dynamic> map, String id) {
    return VoucherModel(
      id: id,
      code: map['code'] ?? '',
      type: map['type'] ?? 'percentage',
      value: (map['value'] as num? ?? 0.0).toDouble(),
      minPurchase: (map['minPurchase'] as num? ?? 0.0).toDouble(),
    );
  }
}
