import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'subscription_models.dart';
import 'subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
              Theme.of(context).colorScheme.tertiaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<SubscriptionProvider>(
            builder: (context, provider, _) {
              return CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    floating: true,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              _buildHeader(context, provider),
                              const SizedBox(height: 32),

                              // Features
                              _buildFeatures(context),
                              const SizedBox(height: 40),

                              // Subscription Cards
                              if (provider.isLoggedIn) ...[
                                _buildSubscriptionCards(context, provider),
                                const SizedBox(height: 24),
                              ],

                              // Auth/Action Buttons
                              _buildActionButtons(context, provider),
                              const SizedBox(height: 16),

                              // Restore Purchases
                              if (provider.isLoggedIn)
                                _buildRestoreButton(context, provider),

                              const SizedBox(height: 32),

                              // Terms & Privacy
                              _buildLegalLinks(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────────── HEADER ─────────────────
  Widget _buildHeader(BuildContext context, SubscriptionProvider provider) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.isSubscribed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Active Subscription',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re Premium! 🎉',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoying ad-free experience • ${provider.subscription.daysRemaining} days left',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber, Colors.orange],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                'Premium',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Upgrade to Premium',
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Remove all ads and enjoy uninterrupted experience',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ───────────────── FEATURES ─────────────────
  Widget _buildFeatures(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final features = [
      _Feature(Icons.block, 'No Banner Ads', 'Clean interface without distractions'),
      _Feature(Icons.fast_forward, 'No Interstitial Ads', 'Seamless app experience'),
      _Feature(Icons.devices, 'Multi-Device Sync', 'Works on all your devices'),
      _Feature(Icons.speed, 'Faster Performance', 'No ad loading delays'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What You Get',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      feature.subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ───────────────── SUBSCRIPTION CARDS ─────────────────
  Widget _buildSubscriptionCards(BuildContext context, SubscriptionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _SubscriptionCard(
          product: SubscriptionProduct.yearly,
          price: provider.getPrice(SubscriptionProduct.yearly),
          badge: 'BEST VALUE',
          savings: 'Save 16.67%',
          onTap: () => _handlePurchase(context, provider, SubscriptionProduct.yearly),
          isLoading: provider.isProcessing,
        ),
        const SizedBox(height: 12),
        _SubscriptionCard(
          product: SubscriptionProduct.monthly,
          price: provider.getPrice(SubscriptionProduct.monthly),
          onTap: () => _handlePurchase(context, provider, SubscriptionProduct.monthly),
          isLoading: provider.isProcessing,
        ),
      ],
    );
  }

  // ───────────────── ACTION BUTTONS ─────────────────
  Widget _buildActionButtons(BuildContext context, SubscriptionProvider provider) {
    if (!provider.isLoggedIn) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: provider.isProcessing
                  ? null
                  : () => _handleGoogleSignIn(context, provider),
              icon: provider.isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Image.asset('assets/google_logo.png', height: 24),
              label: Text(provider.isProcessing
                  ? 'Signing in...'
                  : 'Continue with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to manage your subscription',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (provider.isSubscribed) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _showManageSubscriptionDialog(context),
              icon: const Icon(Icons.settings),
              label: const Text('Manage Subscription'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ───────────────── RESTORE BUTTON ─────────────────
  Widget _buildRestoreButton(BuildContext context, SubscriptionProvider provider) {
    return Center(
      child: TextButton.icon(
        onPressed: provider.isProcessing
            ? null
            : () => _handleRestore(context, provider),
        icon: provider.isProcessing
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.refresh),
        label: Text(provider.isProcessing
            ? 'Restoring...'
            : 'Restore Purchases'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // ───────────────── LEGAL LINKS ─────────────────
  Widget _buildLegalLinks(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () {
            // Open terms
          },
          child: Text(
            'Terms of Service',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        Text('•', style: textTheme.bodySmall),
        TextButton(
          onPressed: () {
            // Open privacy
          },
          child: Text(
            'Privacy Policy',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────── HANDLERS ─────────────────
  Future<void> _handleGoogleSignIn(BuildContext context, SubscriptionProvider provider) async {
    final success = await provider.signInWithGoogle();
    if (!success && provider.errorMessage != null && context.mounted) {
      _showErrorDialog(context, provider.errorMessage!);
    }
  }

  Future<void> _handlePurchase(
      BuildContext context,
      SubscriptionProvider provider,
      SubscriptionProduct product,
      ) async {
    await provider.buySubscription(product);

    if (provider.errorMessage != null && context.mounted) {
      _showErrorDialog(context, provider.errorMessage!);
    } else if (provider.isSubscribed && context.mounted) {
      _showSuccessDialog(context);
    }
  }

  Future<void> _handleRestore(BuildContext context, SubscriptionProvider provider) async {
    final success = await provider.restorePurchases();

    if (context.mounted) {
      if (success) {
        _showSuccessDialog(context, message: 'Purchases restored successfully!');
      } else if (provider.errorMessage != null) {
        _showErrorDialog(context, provider.errorMessage!);
      }
    }
  }

  void _showSuccessDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Success!'),
        content: Text(message ?? 'Premium subscription activated!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManageSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: const Text(
          'To manage or cancel your subscription, please visit the Google Play Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              // Open Play Store subscriptions
              Navigator.pop(context);
            },
            child: const Text('Open Play Store'),
          ),
        ],
      ),
    );
  }
}

// ───────────────── SUBSCRIPTION CARD ─────────────────
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionProduct product;
  final String price;
  final String? badge;
  final String? savings;
  final VoidCallback onTap;
  final bool isLoading;

  const _SubscriptionCard({
    required this.product,
    required this.price,
    this.badge,
    this.savings,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasRecommendation = badge != null;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: hasRecommendation
                ? LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.secondary.withOpacity(0.1),
              ],
            )
                : null,
            color: hasRecommendation ? null : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasRecommendation
                  ? colorScheme.primary
                  : colorScheme.outline,
              width: hasRecommendation ? 2 : 1,
            ),
            boxShadow: hasRecommendation
                ? [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (savings != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                savings!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            product == SubscriptionProduct.monthly
                                ? '/month'
                                : '/year',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isLoading
                        ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                        : Text(
                      'Subscribe',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasRecommendation)
          Positioned(
            top: -1,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                badge!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────── FEATURE MODEL ─────────────────
class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;

  _Feature(this.icon, this.title, this.subtitle);
}