import 'subscription_service.dart';

class FdroidSubscriptionService extends SubscriptionService {
  @override
  Future<void> initialize() async {
    entitled = true;
  }

  @override
  Future<List<SubscriptionProduct>> getProducts() async {
    return [];
  }

  @override
  Future<bool> purchase(String productId) async {
    return true;
  }

  @override
  Future<bool> restorePurchases() async {
    return true;
  }

  @override
  void dispose() {}
}
