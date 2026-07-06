import 'fdroid_subscription_service.dart';
import 'gplay_subscription_service.dart';

const _subscriptionsEnabled = bool.fromEnvironment(
  'SUBSCRIPTIONS_ENABLED',
  defaultValue: false,
);

SubscriptionService createSubscriptionService() {
  if (_subscriptionsEnabled) {
    return GplaySubscriptionService();
  }
  return FdroidSubscriptionService();
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
