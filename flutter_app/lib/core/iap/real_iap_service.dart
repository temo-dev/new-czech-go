import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_models.dart';
import 'iap_service.dart';

/// Bridge from a successful StoreKit purchase to the V17 backend
/// `/v1/iap/apple/verify` endpoint. Decoupled from [AuthService] so
/// tests can drive the verify path without a running HTTP backend.
typedef VerifyReceiptFn = Future<void> Function({
  required String receipt,
  required String productId,
});

/// Slim seam over `InAppPurchase.instance` so [RealIAPService] can be
/// driven from a fake in unit tests. The plugin singleton is concrete
/// and not subclassable; this interface exposes only what V25 uses.
abstract class InAppPurchaseClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases({String? applicationUserName});
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// Default [InAppPurchaseClient] that defers to the platform plugin.
/// Wired from `main.dart` for production builds; tests substitute
/// [_FakeInAppPurchaseClient] (defined alongside the test).
class PluginInAppPurchaseClient implements InAppPurchaseClient {
  PluginInAppPurchaseClient([InAppPurchase? plugin])
      : _plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase _plugin;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _plugin.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _plugin.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _plugin.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _plugin.restorePurchases(applicationUserName: applicationUserName);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _plugin.completePurchase(purchase);
}

/// Production [IAPService] backed by `in_app_purchase`. Owns the
/// purchase observer for the lifetime of the app — instantiate once
/// in `main.dart`, call [start] post-`runApp`, and leave it running.
///
/// Buy + restore are async because StoreKit delivers the result on
/// [InAppPurchase.purchaseStream] *after* the platform sheet returns.
/// The service holds a per-product [Completer] so callers see the
/// future surface they expect (resolved on PURCHASED / RESTORED,
/// rejected on ERROR / CANCELED).
class RealIAPService implements IAPService {
  RealIAPService({
    required this.verifyReceipt,
    InAppPurchaseClient? client,
  }) : _client = client ?? PluginInAppPurchaseClient();

  /// Posts a successful StoreKit receipt to the backend. Production
  /// wiring shells out to `AuthService.apiClientForScreens.verifyAppleReceiptV17`
  /// + `AuthService.refresh()`; tests stub this directly.
  final VerifyReceiptFn verifyReceipt;

  final InAppPurchaseClient _client;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<IAPPurchase>> _pendingBuy = {};
  final List<IAPPurchase> _restoredCache = [];

  /// Subscribes to [InAppPurchaseClient.purchaseStream]. Idempotent —
  /// safe to call from `main.dart` even if the service was already
  /// started (`start()` is a no-op when the subscription is live).
  void start() {
    _sub ??= _client.purchaseStream.listen(_onPurchaseUpdate);
  }

  /// Cancels the observer. Safe to call multiple times.
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  Future<List<IAPProduct>> loadProducts() async {
    final resp = await _client.queryProductDetails(IAPProducts.all.toSet());
    return resp.productDetails
        .map((pd) => IAPProduct(
              id: pd.id,
              title: pd.title.isEmpty ? pd.id : pd.title,
              priceLabel: pd.price,
              priceAmount: pd.rawPrice,
              currency: pd.currencyCode,
            ))
        .toList(growable: false);
  }

  @override
  Future<IAPPurchase> buy(String productId) async {
    final resp = await _client.queryProductDetails({productId});
    if (resp.notFoundIDs.isNotEmpty || resp.productDetails.isEmpty) {
      throw IAPException(
        code: 'product_not_found',
        message: 'Sản phẩm không có sẵn.',
      );
    }
    // Replace any in-flight Completer for this product so a stale buy
    // never resolves the new caller's future. The previous one is
    // discarded — the StoreKit observer will see no listener and
    // simply log.
    _pendingBuy[productId] = Completer<IAPPurchase>();

    try {
      await _client.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: resp.productDetails.first),
      );
    } catch (e) {
      _pendingBuy.remove(productId);
      throw IAPException(
        code: 'buy_failed',
        message: e.toString(),
      );
    }
    return _pendingBuy[productId]!.future;
  }

  @override
  Future<List<IAPPurchase>> restorePurchases() async {
    _restoredCache.clear();
    await _client.restorePurchases();
    // _restoredCache is populated by the observer as RESTORED events
    // arrive. Returning a copy decouples callers from the live list.
    return List<IAPPurchase>.unmodifiable(_restoredCache);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final pd in updates) {
      switch (pd.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndSettle(pd);
          break;
        case PurchaseStatus.error:
          _failPending(pd.productID, pd.error?.message ?? 'Mua thất bại');
          await _completeIfPending(pd);
          break;
        case PurchaseStatus.canceled:
          _failPending(pd.productID, 'Đã hủy');
          await _completeIfPending(pd);
          break;
        case PurchaseStatus.pending:
          // Apple may queue a payment that is awaiting parental
          // approval ("Ask to Buy"). Leave the Completer pending; the
          // observer will fire again with PURCHASED or ERROR later.
          break;
      }
    }
  }

  Future<void> _verifyAndSettle(PurchaseDetails pd) async {
    try {
      await verifyReceipt(
        receipt: pd.verificationData.serverVerificationData,
        productId: pd.productID,
      );
      final purchase = IAPPurchase(
        transactionId: pd.purchaseID ?? '',
        productId: pd.productID,
        receipt: pd.verificationData.serverVerificationData,
      );
      _completePending(pd.productID, purchase);
      if (pd.status == PurchaseStatus.restored) {
        _restoredCache.add(purchase);
      }
    } catch (e) {
      _failPending(pd.productID, 'Xác thực thất bại: $e');
    } finally {
      // Complete the StoreKit transaction queue regardless of verify
      // outcome — failing to do so floods the queue and Apple rejects
      // the next launch with "transaction queue not finished".
      await _completeIfPending(pd);
    }
  }

  Future<void> _completeIfPending(PurchaseDetails pd) async {
    if (pd.pendingCompletePurchase) {
      await _client.completePurchase(pd);
    }
  }

  void _completePending(String productId, IAPPurchase purchase) {
    final completer = _pendingBuy.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(purchase);
    }
  }

  void _failPending(String productId, String reason) {
    final completer = _pendingBuy.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        IAPException(code: 'purchase_failed', message: reason),
      );
    }
  }
}
