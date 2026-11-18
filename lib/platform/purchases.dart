/// In-app purchases (coin packs, station scenes bought with money).
///
/// Store rules: digital items sold inside the app must use Apple In-App
/// Purchase / Google Play Billing. The real implementation is added before
/// release; until then [NotReadyPurchases] answers "not available yet".
abstract class Purchases {
  /// Buy [productId]. Returns true when the store confirms payment.
  Future<PurchaseOutcome> buy(String productId);
}

enum PurchaseOutcome { purchased, cancelled, notAvailable }

class NotReadyPurchases implements Purchases {
  const NotReadyPurchases();
  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.notAvailable;
}
