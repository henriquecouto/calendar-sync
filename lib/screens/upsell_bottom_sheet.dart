import 'package:flutter/material.dart';

import '../main.dart';
import '../subscriptions/subscription_service.dart';
import 'subscription_screen.dart';

class UpsellBottomSheet extends StatefulWidget {
  const UpsellBottomSheet({super.key});

  @override
  State<UpsellBottomSheet> createState() => _UpsellBottomSheetState();
}

class _UpsellBottomSheetState extends State<UpsellBottomSheet> {
  List<SubscriptionProduct> _products = [];
  bool _loading = true;
  String? _loadingProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await subscriptionService.getProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }
  }

  Future<void> _subscribe(String productId) async {
    setState(() => _loadingProductId = productId);
    final success = await subscriptionService.purchase(productId);
    if (mounted) {
      setState(() => _loadingProductId = null);
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.workspace_premium,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Unlock Unlimited Profiles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve reached the free limit of 1 profile. '
              'Unlock unlimited profiles with CalSync Premium.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._products.map((product) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: _loadingProductId == product.id
                          ? null
                          : () => _subscribe(product.id),
                      icon: _loadingProductId == product.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.shopping_cart),
                      label: Text(
                        '${product.title} — ${product.price}/${product.period}',
                      ),
                    ),
                  )),
            if (!_loading && _products.isEmpty) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View Plans'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              child: const Text('Restore Purchases'),
            ),
          ],
        ),
      ),
    );
  }
}
