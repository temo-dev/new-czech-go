/// Identifier constants matching the App Store Connect product IDs.
class IAPProducts {
  static const monthly = 'eu.hadoo.czechgo.pro.monthly';
  static const yearly = 'eu.hadoo.czechgo.pro.yearly';

  static const all = [monthly, yearly];
}

/// One subscription product as returned by [IAPService.loadProducts].
class IAPProduct {
  const IAPProduct({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.priceAmount,
    required this.currency,
  });

  final String id;
  final String title;
  final String priceLabel; // already-localized "99.000 ₫" string
  final double priceAmount;
  final String currency;

  bool get isMonthly => id == IAPProducts.monthly;
  bool get isYearly => id == IAPProducts.yearly;
}

/// Outcome of a successful purchase. The transaction id + receipt are
/// what the backend `/v1/iap/apple/verify` endpoint validates.
class IAPPurchase {
  const IAPPurchase({
    required this.transactionId,
    required this.productId,
    required this.receipt,
  });

  final String transactionId;
  final String productId;
  final String receipt;
}

/// Typed error the IAP layer throws. The UI switches on [code] for
/// localized error toasts.
class IAPException implements Exception {
  IAPException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'IAPException($code): $message';
}
