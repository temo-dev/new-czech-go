import 'dart:async';

import 'package:flutter_app/core/iap/iap_models.dart';
import 'package:flutter_app/core/iap/real_iap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeInAppPurchaseClient implements InAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  ProductDetailsResponse queryResponse = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  bool buyResult = true;
  Object? buyError;
  int buyCalls = 0;
  int restoreCalls = 0;
  List<PurchaseDetails> restoreEmissions = const [];
  final List<PurchaseDetails> completed = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    if (queryResponse.productDetails.isEmpty && queryResponse.notFoundIDs.isEmpty) {
      // Default to "everything found" for the requested IDs unless the
      // test set up a richer response.
      return ProductDetailsResponse(
        productDetails: identifiers.map(_makeProductDetails).toList(),
        notFoundIDs: const [],
      );
    }
    return queryResponse;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls += 1;
    if (buyError != null) {
      throw buyError!;
    }
    return buyResult;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls += 1;
    // Mirror StoreKit: events arrive on the purchase stream while
    // restorePurchases() is in flight. Emit synchronously so the
    // observer-driven cache is populated before the future returns.
    if (restoreEmissions.isNotEmpty) {
      _controller.add(restoreEmissions);
      // Yield once so listeners run before we resolve.
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  void emit(List<PurchaseDetails> updates) {
    _controller.add(updates);
  }

  Future<void> close() async {
    await _controller.close();
  }
}

ProductDetails _makeProductDetails(String id) {
  return ProductDetails(
    id: id,
    title: 'Pro $id',
    description: '',
    price: '99.000 ₫',
    rawPrice: 99000,
    currencyCode: 'VND',
  );
}

PurchaseDetails _makePurchase({
  required String productId,
  required PurchaseStatus status,
  String purchaseId = 'txn_001',
  String receipt = 'fake-receipt',
  IAPError? error,
  bool pendingCompletePurchase = true,
}) {
  final details = PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: receipt,
      serverVerificationData: receipt,
      source: 'app_store',
    ),
    transactionDate: '${DateTime.now().millisecondsSinceEpoch}',
    status: status,
  );
  if (error != null) {
    details.error = error;
  }
  details.pendingCompletePurchase = pendingCompletePurchase;
  return details;
}

VerifyReceiptFn _recordingVerifier({
  bool throws = false,
  List<Map<String, String>>? sink,
}) {
  return ({required String receipt, required String productId}) async {
    sink?.add({'receipt': receipt, 'productId': productId});
    if (throws) {
      throw StateError('verify failed');
    }
  };
}

void main() {
  group('RealIAPService.loadProducts', () {
    test('maps StoreKit ProductDetails to IAPProduct', () async {
      final client = _FakeInAppPurchaseClient();
      client.queryResponse = ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: IAPProducts.monthly,
            title: 'Pro hàng tháng',
            description: '',
            price: '99.000 ₫',
            rawPrice: 99000,
            currencyCode: 'VND',
          ),
          ProductDetails(
            id: IAPProducts.yearly,
            title: 'Pro hàng năm',
            description: '',
            price: '790.000 ₫',
            rawPrice: 790000,
            currencyCode: 'VND',
          ),
        ],
        notFoundIDs: const [],
      );
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(),
        client: client,
      );
      addTearDown(service.dispose);
      addTearDown(client.close);

      final products = await service.loadProducts();
      expect(products, hasLength(2));
      expect(products.first.id, IAPProducts.monthly);
      expect(products.first.priceLabel, '99.000 ₫');
      expect(products.first.priceAmount, 99000);
      expect(products.first.currency, 'VND');
      expect(products.last.id, IAPProducts.yearly);
    });
  });

  group('RealIAPService.buy', () {
    test('happy path: purchaseStream PURCHASED → verify → resolve', () async {
      final client = _FakeInAppPurchaseClient();
      final calls = <Map<String, String>>[];
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(sink: calls),
        client: client,
      )..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      final future = service.buy(IAPProducts.monthly);

      // Allow buy() to install the Completer + invoke buyNonConsumable.
      await Future<void>.delayed(Duration.zero);

      client.emit([
        _makePurchase(
          productId: IAPProducts.monthly,
          status: PurchaseStatus.purchased,
          purchaseId: 'txn_buy_1',
          receipt: 'happy-receipt',
        ),
      ]);

      final purchase = await future;
      expect(purchase.transactionId, 'txn_buy_1');
      expect(purchase.productId, IAPProducts.monthly);
      expect(purchase.receipt, 'happy-receipt');
      expect(calls, hasLength(1));
      expect(calls.first['receipt'], 'happy-receipt');
      expect(client.buyCalls, 1);
      expect(client.completed, hasLength(1)); // queue cleared
    });

    test('canceled: purchaseStream CANCELED → IAPException', () async {
      final client = _FakeInAppPurchaseClient();
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(),
        client: client,
      )..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      final future = service.buy(IAPProducts.monthly);
      await Future<void>.delayed(Duration.zero);

      client.emit([
        _makePurchase(
          productId: IAPProducts.monthly,
          status: PurchaseStatus.canceled,
        ),
      ]);

      await expectLater(
        future,
        throwsA(isA<IAPException>().having(
          (e) => e.code,
          'code',
          'purchase_failed',
        )),
      );
    });

    test('error: purchaseStream ERROR → IAPException with platform message',
        () async {
      final client = _FakeInAppPurchaseClient();
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(),
        client: client,
      )..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      final future = service.buy(IAPProducts.monthly);
      await Future<void>.delayed(Duration.zero);

      client.emit([
        _makePurchase(
          productId: IAPProducts.monthly,
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'app_store',
            code: 'storekit_failed',
            message: 'StoreKit timed out',
          ),
        ),
      ]);

      await expectLater(
        future,
        throwsA(isA<IAPException>().having(
          (e) => e.message,
          'message',
          contains('StoreKit timed out'),
        )),
      );
    });
  });

  group('RealIAPService.restorePurchases', () {
    test('emits cached IAPPurchase per RESTORED event', () async {
      final client = _FakeInAppPurchaseClient();
      final calls = <Map<String, String>>[];
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(sink: calls),
        client: client,
      )..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      // The fake mirrors StoreKit: restorePurchases() pushes RESTORED
      // events on the purchase stream while in flight, populating the
      // observer cache before returning.
      client.restoreEmissions = [
        _makePurchase(
          productId: IAPProducts.yearly,
          status: PurchaseStatus.restored,
          purchaseId: 'txn_restore_1',
          receipt: 'restored-receipt',
        ),
      ];

      final result = await service.restorePurchases();
      expect(client.restoreCalls, 1);
      expect(result, hasLength(1));
      expect(result.first.transactionId, 'txn_restore_1');
      expect(result.first.receipt, 'restored-receipt');
      expect(calls.single['receipt'], 'restored-receipt');
    });
  });

  group('RealIAPService verify error propagation', () {
    test('verify throws → completer fails with IAPException, queue still cleared',
        () async {
      final client = _FakeInAppPurchaseClient();
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(throws: true),
        client: client,
      )..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      final future = service.buy(IAPProducts.monthly);
      await Future<void>.delayed(Duration.zero);

      client.emit([
        _makePurchase(
          productId: IAPProducts.monthly,
          status: PurchaseStatus.purchased,
        ),
      ]);

      await expectLater(
        future,
        throwsA(isA<IAPException>().having(
          (e) => e.message,
          'message',
          contains('Xác thực thất bại'),
        )),
      );
      // Queue MUST still be cleared — leaving it open floods StoreKit
      // and trips the next-launch "transaction queue not finished".
      expect(client.completed, hasLength(1));
    });
  });

  group('RealIAPService.start is idempotent', () {
    test('calling start twice does not double-subscribe', () async {
      final client = _FakeInAppPurchaseClient();
      final calls = <Map<String, String>>[];
      final service = RealIAPService(
        verifyReceipt: _recordingVerifier(sink: calls),
        client: client,
      )
        ..start()
        ..start();
      addTearDown(service.dispose);
      addTearDown(client.close);

      final future = service.buy(IAPProducts.monthly);
      await Future<void>.delayed(Duration.zero);

      client.emit([
        _makePurchase(
          productId: IAPProducts.monthly,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await future;
      // If start() had double-subscribed, verifyReceipt would fire twice.
      expect(calls, hasLength(1));
    });
  });
}
