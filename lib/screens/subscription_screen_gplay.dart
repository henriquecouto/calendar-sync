import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../subscriptions/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionProduct> _products = [];
  bool _loading = true;
  String? _loadingProductId;
  bool _restoring = false;

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
      setState(() {
        _loadingProductId = null;
        if (success) {
          _load();
        }
      });
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final success = await subscriptionService.restorePurchases();
    if (mounted) {
      setState(() {
        _restoring = false;
        if (success) {
          _load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSubscribed = subscriptionService.isSubscribed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalSync Premium'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    isSubscribed
                        ? Icons.workspace_premium
                        : Icons.workspace_premium_outlined,
                    size: 56,
                    color: isSubscribed
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSubscribed
                        ? 'You\'re a Premium Member'
                        : 'Go Premium',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSubscribed
                        ? 'Enjoy unlimited sync profiles and full access to all features.'
                        : 'Unlock unlimited sync profiles with a subscription.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (isSubscribed) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(
                            'https://play.google.com/store/account/subscriptions'
                            '?package=dev.henriquecouto.calsync_gplay',
                          ),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Manage Subscription'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isSubscribed && _loading)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!isSubscribed && !_loading) ...[
            const SizedBox(height: 16),
            for (final product in _products)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${product.price}/${product.period}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _loadingProductId == product.id
                                  ? null
                                  : () => _subscribe(product.id),
                              child: _loadingProductId == product.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Subscribe'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_products.isEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No subscription plans available. Please try again later.',
                    style: TextStyle(color: colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _restoring ? null : _restore,
              icon: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore),
              label: const Text('Restore Purchases'),
            ),
          ],
        ],
      ),
    );
  }
}
