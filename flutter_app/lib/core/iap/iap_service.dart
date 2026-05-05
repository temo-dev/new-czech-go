import 'iap_models.dart';

/// Abstract surface the Paywall consumes. Decouples the UI from the
/// concrete StoreKit / Google Play binding so:
///   - widget tests can drive the flow with a [StubIAPService]
///   - the V18-polish swap to the real `in_app_purchase` package
///     edits exactly one file
///
/// In V17 production builds, IAP is wired via a real implementation
/// hooked up at the AppShell level. Until that production ipmlementation
/// lands (see V18 polish in docs/specs/self-serve-learner-spec.md
/// §10), the paywall ships behind a build flag and shows a "coming
/// soon" path on Buy.
abstract class IAPService {
  Future<List<IAPProduct>> loadProducts();
  Future<IAPPurchase> buy(String productId);
  Future<List<IAPPurchase>> restorePurchases();
}

/// Default placeholder implementation. Returns hardcoded product data
/// so the paywall is testable without a real StoreKit handshake; throws
/// [IAPException] code `not_implemented` on buy/restore so the UI
/// surfaces a clear "coming soon" message during dev + TestFlight beta.
///
/// Production builds replace this with the in_app_purchase-backed
/// adapter; the swap lives in main.dart's wiring of [IAPService].
class StubIAPService implements IAPService {
  @override
  Future<List<IAPProduct>> loadProducts() async {
    return const [
      IAPProduct(
        id: IAPProducts.monthly,
        title: 'Pro hàng tháng',
        priceLabel: '99.000 ₫ / tháng',
        priceAmount: 99000,
        currency: 'VND',
      ),
      IAPProduct(
        id: IAPProducts.yearly,
        title: 'Pro hàng năm',
        priceLabel: '990.000 ₫ / năm',
        priceAmount: 990000,
        currency: 'VND',
      ),
    ];
  }

  @override
  Future<IAPPurchase> buy(String productId) async {
    throw IAPException(
      code: 'not_implemented',
      message: 'Mua Pro chưa khả dụng trong build này. App Store sẽ có sẵn sau khi ra mắt.',
    );
  }

  @override
  Future<List<IAPPurchase>> restorePurchases() async {
    return const [];
  }
}
