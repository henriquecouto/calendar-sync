import 'fdroid_subscription_service.dart';

SubscriptionService createSubscriptionService() {
  return FdroidSubscriptionService();
}

Future<bool> queryBackgroundEntitlement() async {
  return true;
}

class SubscriptionProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final String period;

  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.period,
  });
}

abstract class SubscriptionService {
  bool entitled = false;
  void Function(bool isSubscribed)? onStatusChanged;

  bool get isSubscribed => entitled;

  Future<void> initialize();

  Future<List<SubscriptionProduct>> getProducts();

  Future<bool> purchase(String productId);

  Future<bool> restorePurchases();

  void dispose();
}
