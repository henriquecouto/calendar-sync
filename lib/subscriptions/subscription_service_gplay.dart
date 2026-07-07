import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

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

const _productIdMonthly = 'premium_monthly';
const _productIdYearly = 'premium_yearly';

Future<bool> queryBackgroundEntitlement() async {
  if (!_subscriptionsEnabled) return true;

  try {
    final addition = InAppPurchasePlatformAddition.instance;
    if (addition is InAppPurchaseAndroidPlatformAddition) {
      final response = await addition.queryPastPurchases();
      if (response.error == null) {
        for (final purchase in response.pastPurchases) {
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            if (purchase.productID == _productIdMonthly ||
                purchase.productID == _productIdYearly) {
              return true;
            }
          }
        }
      }
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('subscription_entitled') ?? false;
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
