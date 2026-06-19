import 'package:cloud_firestore/cloud_firestore.dart';

class OrderProductSnapshot {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String imageUrl;

  OrderProductSnapshot({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
    };
  }

  factory OrderProductSnapshot.fromMap(Map<String, dynamic> map) {
    return OrderProductSnapshot(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      price: (map['price'] as num? ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}

class OrderStatusHistory {
  final String status;
  final DateTime timestamp;
  final String note;

  OrderStatusHistory({
    required this.status,
    required this.timestamp,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'note': note,
    };
  }

  factory OrderStatusHistory.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistory(
      status: map['status'] ?? 'Pending',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      note: map['note'] ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String email;
  final String userId;
  final String address;
  final List<OrderProductSnapshot> items;
  final double total;
  final List<OrderStatusHistory> statusHistory;
  final DateTime createdAt;
  final String? promoCode;
  final double discount;

  OrderModel({
    required this.id,
    required this.email,
    required this.userId,
    required this.address,
    required this.items,
    required this.total,
    required this.statusHistory,
    required this.createdAt,
    this.promoCode,
    this.discount = 0.0,
  });

  String get currentStatus {
    if (statusHistory.isEmpty) return 'Pending';
    return statusHistory.last.status;
  }

  /// All possible order statuses in order
  static const List<String> allStatuses = [
    'Pending',
    'Processing',
    'Packed',
    'Shipped',
    'Out For Delivery',
    'Delivered',
    'Cancelled',
  ];

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'userId': userId,
      'address': address,
      'items': items.map((x) => x.toMap()).toList(),
      'total': total,
      'statusHistory': statusHistory.map((x) => x.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'promoCode': promoCode,
      'discount': discount,
    };
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawHistory = map['statusHistory'] as List?;
    final history = rawHistory != null
        ? rawHistory.map((x) => OrderStatusHistory.fromMap(Map<String, dynamic>.from(x))).toList()
        : <OrderStatusHistory>[];

    final created = map['createdAt'] != null
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    // Migration/Legacy Fallback
    if (history.isEmpty) {
      final legacyStatus = map['status'] as String? ?? 'Pending';
      history.add(OrderStatusHistory(
        status: legacyStatus,
        timestamp: created,
        note: 'Order initiated',
      ));
    }

    final rawItems = map['items'] as List? ?? [];
    final parsedItems = rawItems
        .map((x) => OrderProductSnapshot.fromMap(Map<String, dynamic>.from(x)))
        .toList();

    return OrderModel(
      id: id,
      email: map['email'] ?? '',
      userId: map['userId'] ?? '',
      address: map['address'] ?? '',
      items: parsedItems,
      total: (map['total'] as num? ?? 0.0).toDouble(),
      statusHistory: history,
      createdAt: created,
      promoCode: map['promoCode'] as String?,
      discount: (map['discount'] as num? ?? 0.0).toDouble(),
    );
  }
}
