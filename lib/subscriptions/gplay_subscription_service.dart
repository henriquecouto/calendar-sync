import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'subscription_service.dart';

const _productIdMonthly = 'premium_monthly';
const _productIdYearly = 'premium_yearly';

class GplaySubscriptionService extends SubscriptionService
    with WidgetsBindingObserver {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final available = await _iap.isAvailable();
    if (!available) return;

    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);
    WidgetsBinding.instance.addObserver(this);

    await _querySubscriptionStatus();
  }

  @override
  Future<List<SubscriptionProduct>> getProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return [];

    final response = await _iap.queryProductDetails({
      _productIdMonthly,
      _productIdYearly,
    });

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'GPlay billing: products not found: ${response.notFoundIDs}',
      );
    }

    return response.productDetails.map((p) {
      return SubscriptionProduct(
        id: p.id,
        title: p.title,
        description: p.description,
        price: p.price,
        currencyCode: p.currencyCode,
        period: _formatPeriod(p),
      );
    }).toList();
  }

  @override
  Future<bool> purchase(String productId) async {
    final detailsResponse = await _iap.queryProductDetails({productId});
    if (detailsResponse.productDetails.isEmpty) return false;

    final purchaseParam = PurchaseParam(
      productDetails: detailsResponse.productDetails.first,
    );

    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<bool> restorePurchases() async {
    await _querySubscriptionStatus();
    return entitled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _querySubscriptionStatus();
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> _querySubscriptionStatus() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    bool hasActiveSub = false;

    try {
      final addition =
          InAppPurchasePlatformAddition.instance;
      if (addition is InAppPurchaseAndroidPlatformAddition) {
        final response = await addition.queryPastPurchases();
        if (response.error == null) {
          for (final purchase in response.pastPurchases) {
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              if (purchase.productID == _productIdMonthly ||
                  purchase.productID == _productIdYearly) {
                hasActiveSub = true;
                break;
              }
            }
          }
        }
      }
    } catch (_) {
      await _iap.restorePurchases();
      return;
    }

    final previous = entitled;
    entitled = hasActiveSub;

    if (previous != entitled) {
      onStatusChanged?.call(entitled);
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == _productIdMonthly ||
              purchase.productID == _productIdYearly) {
            final previous = entitled;
            entitled = true;
            if (previous != entitled) {
              onStatusChanged?.call(entitled);
            }
          }
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          debugPrint('GPlay purchase error: ${purchase.error}');
          break;
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  String _formatPeriod(ProductDetails product) {
    if (product.id == _productIdMonthly) return 'month';
    if (product.id == _productIdYearly) return 'year';
    return '';
  }
}
