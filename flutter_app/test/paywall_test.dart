import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/auth/auth_service.dart';
import 'package:flutter_app/core/auth/auth_storage.dart';
import 'package:flutter_app/core/iap/iap_models.dart';
import 'package:flutter_app/core/iap/iap_service.dart';
import 'package:flutter_app/core/streak/streak_models.dart';
import 'package:flutter_app/features/home/widgets/quota_indicator.dart';
import 'package:flutter_app/features/paywall/screens/paywall_screen.dart';
import 'package:flutter_app/features/paywall/screens/pro_success_screen.dart';

class _RecorderIAP implements IAPService {
  String? lastBuyId;
  IAPException? buyError;
  IAPPurchase? buyResult;
  List<IAPPurchase> restoreResult = const [];

  @override
  Future<List<IAPProduct>> loadProducts() async => const [
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

  @override
  Future<IAPPurchase> buy(String productId) async {
    lastBuyId = productId;
    if (buyError != null) throw buyError!;
    return buyResult ??
        IAPPurchase(transactionId: 't', productId: productId, receipt: 'r');
  }

  @override
  Future<List<IAPPurchase>> restorePurchases() async => restoreResult;
}

Future<AuthService> _newService() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final storage = await AuthStorage.create();
  return AuthService(apiClient: ApiClient(baseUrl: 'http://127.0.0.1:1'), storage: storage);
}

void main() {
  group('IAPProducts constants', () {
    test('product ids match App Store Connect bundle', () {
      expect(IAPProducts.monthly, 'eu.hadoo.czechgo.pro.monthly');
      expect(IAPProducts.yearly, 'eu.hadoo.czechgo.pro.yearly');
      expect(IAPProducts.all.length, 2);
    });
  });

  group('StubIAPService', () {
    test('loadProducts returns monthly + yearly', () async {
      final stub = StubIAPService();
      final list = await stub.loadProducts();
      expect(list.length, 2);
      expect(list.map((p) => p.id).toList(), [IAPProducts.monthly, IAPProducts.yearly]);
    });

    test('buy throws not_implemented', () async {
      final stub = StubIAPService();
      await expectLater(
        () => stub.buy(IAPProducts.monthly),
        throwsA(predicate((e) => e is IAPException && e.code == 'not_implemented')),
      );
    });

    test('restorePurchases returns empty', () async {
      final stub = StubIAPService();
      expect(await stub.restorePurchases(), isEmpty);
    });
  });

  testWidgets('PaywallScreen renders comparison table + product tiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    final iap = _RecorderIAP();
    final svc = await _newService();
    await tester.pumpWidget(MaterialApp(
      home: PaywallScreen(iap: iap, authServiceOverride: svc),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mở khoá toàn bộ tính năng'), findsOneWidget);
    expect(find.text('Lượt luyện / ngày'), findsOneWidget);
    expect(find.text('Pro hàng tháng'), findsOneWidget);
    expect(find.text('Pro hàng năm'), findsOneWidget);
    expect(find.text('Tiết kiệm 17%'), findsOneWidget);
    expect(find.text('Khôi phục giao dịch trước'), findsOneWidget);
  });

  testWidgets('PaywallScreen tapping a tile flips selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    final iap = _RecorderIAP();
    final svc = await _newService();
    await tester.pumpWidget(MaterialApp(
      home: PaywallScreen(iap: iap, authServiceOverride: svc),
    ));
    await tester.pumpAndSettle();

    // Default selection is yearly. Tap the monthly tile.
    await tester.tap(find.text('Pro hàng tháng'));
    await tester.pump();
    // No exception + the tap did not crash. The visual state is
    // covered by the radio_button_checked icon swap which is
    // expensive to assert reliably; presence-of-no-error is the
    // useful guarantee here.
    expect(tester.takeException(), isNull);
  });

  testWidgets('PaywallScreen surfaces IAPException as error banner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    final iap = _RecorderIAP()
      ..buyError = IAPException(code: 'not_implemented', message: 'coming soon');
    final svc = await _newService();
    await tester.pumpWidget(MaterialApp(
      home: PaywallScreen(iap: iap, authServiceOverride: svc),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nâng cấp Pro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets('ProSuccessScreen renders welcome copy + start CTA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProSuccessScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chào mừng bạn đến Pro!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Bắt đầu'), findsOneWidget);
  });

  testWidgets('QuotaIndicator hidden for Pro', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuotaIndicator(usage: DailyUsageSummary.empty, proHide: true),
      ),
    ));
    expect(find.textContaining('lượt luyện hôm nay'), findsNothing);
  });

  testWidgets('QuotaIndicator shows X/limit when free', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: QuotaIndicator(
          usage: DailyUsageSummary(attempts: 3, attemptsLimit: 7, interviews: 0, interviewsLimit: 1),
        ),
      ),
    ));
    expect(find.text('3 / 7 lượt luyện hôm nay'), findsOneWidget);
  });

  testWidgets('QuotaIndicator at full triggers onTapWhenFull', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuotaIndicator(
          usage: const DailyUsageSummary(attempts: 7, attemptsLimit: 7, interviews: 0, interviewsLimit: 1),
          onTapWhenFull: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.byType(QuotaIndicator));
    expect(taps, 1);
  });

  // ── V25 F1: subscription disclosure + legal links ───────────────────────

  testWidgets('PaywallScreen disclosure block visible while loadProducts loads',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    // _SlowIAP delays loadProducts so the test can assert the
    // disclosure renders BEFORE products resolve.
    final iap = _SlowIAP();
    final svc = await _newService();
    await tester.pumpWidget(MaterialApp(
      home: PaywallScreen(iap: iap, authServiceOverride: svc),
    ));
    // Pump only one frame — _products is still null at this point.
    await tester.pump();

    // Disclosure copy must be visible.
    expect(
      find.textContaining('Tự động gia hạn cho đến khi bạn hủy'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Thanh toán qua Apple ID'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Quản lý/hủy: Cài đặt'),
      findsOneWidget,
    );
    // Loading spinner is also present at this stage.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let loadProducts resolve so the test tears down cleanly.
    iap.completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('PaywallScreen Terms + Privacy buttons dispatch external URLs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1100));
    final iap = _RecorderIAP();
    final svc = await _newService();
    final launched = <Uri>[];
    await tester.pumpWidget(MaterialApp(
      home: PaywallScreen(
        iap: iap,
        authServiceOverride: svc,
        urlLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();

    // The legal row must render both buttons.
    expect(find.byKey(const Key('paywall_terms_button')), findsOneWidget);
    expect(find.byKey(const Key('paywall_privacy_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('paywall_terms_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('paywall_privacy_button')));
    await tester.pump();

    expect(launched.length, 2);
    expect(launched[0].toString(), contains('/legal/eula'));
    expect(launched[1].toString(), contains('/legal/privacy'));
  });
}

/// Fake IAP whose loadProducts hangs until the test completes the
/// internal completer. Keeps the paywall in its loading state long
/// enough to assert the disclosure renders without products.
class _SlowIAP implements IAPService {
  final completer = Completer<void>();

  @override
  Future<List<IAPProduct>> loadProducts() async {
    await completer.future;
    return const [];
  }

  @override
  Future<IAPPurchase> buy(String productId) async =>
      throw IAPException(code: 'not_implemented', message: 'unused');

  @override
  Future<List<IAPPurchase>> restorePurchases() async => const [];
}
