class ExchangeOffer {
  final String id;
  final String seller;
  final String service;
  final int price;
  final int quantity;
  final String status;
  final int createdAt;

  ExchangeOffer({
    required this.id,
    required this.seller,
    required this.service,
    required this.price,
    required this.quantity,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory ExchangeOffer.fromJson(Map<String, dynamic> json) {
    return ExchangeOffer(
      id: json['id'] as String? ?? '',
      seller: json['seller'] as String? ?? '',
      service: json['service'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExchangeOrder {
  final String id;
  final String buyer;
  final String offerId;
  final int quantity;
  final int totalPrice;
  final String status;
  final int createdAt;

  ExchangeOrder({
    required this.id,
    required this.buyer,
    required this.offerId,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  factory ExchangeOrder.fromJson(Map<String, dynamic> json) {
    return ExchangeOrder(
      id: json['id'] as String? ?? '',
      buyer: json['buyer'] as String? ?? '',
      offerId: json['offer_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExchangeBalance {
  final String citizenId;
  final int amount;

  ExchangeBalance({
    required this.citizenId,
    required this.amount,
  });

  factory ExchangeBalance.fromJson(Map<String, dynamic> json) {
    return ExchangeBalance(
      citizenId: json['citizen_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }
}
