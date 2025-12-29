import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../service/subscription/subscription_models.dart';
import '../../service/subscription/subscription_provider.dart';
import '../condition/privacy_policy.dart';
import '../condition/terms_of_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionProduct? _selectedPlan =
      SubscriptionProduct.yearly; // Default to yearly

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2742), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Consumer<SubscriptionProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  _buildAppBar(context),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Go Premium', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          Text(
                            'Join thousands of users and enjoy an ad-free, premium experience.',
                            style: textTheme.bodyLarge!.copyWith(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _removeAdsText(),
                          const SizedBox(height: 20),

                          _buildPlanCard(
                            title: 'Yearly Plan',
                            badge: 'MOST POPULAR',
                            badgeColor: const Color(0xFFFFD700),
                            savePercentage: '',
                            freeDays: '7 Days Free Trial',
                            price: provider.getPrice(
                              SubscriptionProduct.yearly,
                            ),
                            period: '/ year',
                            product: SubscriptionProduct.yearly,
                          ),
                          const SizedBox(height: 16),
                          _buildPlanCard(
                            title: 'Monthly Plan',
                            savePercentage: 'Save 16%',
                            price: provider.getPrice(
                              SubscriptionProduct.monthly,
                            ),
                            period: '/ month',
                            product: SubscriptionProduct.monthly,
                          ),

                          const SizedBox(height: 20),
                          _buildActionButtons(provider),
                          const SizedBox(height: 20),
                          _buildFooter(provider),
                        ],
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    String? badge,
    Color? badgeColor,
    required String savePercentage,
    String? freeDays,
    required String price,
    required String period,
    required SubscriptionProduct product,
  }) {
    final isSelected = _selectedPlan == product;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          // Glassmorphism effect
          color: isSelected
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF4FACFE) : Colors.white10,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4FACFE).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge, style: textTheme.labelMedium),
                    ),
                  ],
                  Text(
                    title,
                    style: textTheme.displaySmall!.copyWith(
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    freeDays ?? savePercentage,
                    style: textTheme.bodyMedium!.copyWith(
                      color: isSelected
                          ? const Color(0xFF4FACFE)
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '',
                  style: const TextStyle(
                    color: Colors.white30,
                    decoration: TextDecoration.lineThrough,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: textTheme.headlineSmall!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      period,
                      style: textTheme.labelLarge!.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SubscriptionProvider provider) {
    bool isPrimaryActive =
        (_selectedPlan != null &&
        !provider.isProcessing &&
        provider.isLoggedIn);
    bool showSignIn = !provider.isLoggedIn;
    final TextTheme textTheme = Theme.of(context).textTheme;


    return Column(
      children: [
        if (provider.isLoggedIn)
          TextButton(
            onPressed: () => _handleRestore(context, provider),
            child: const Text(
              'Restore Purchases',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isPrimaryActive || showSignIn
                ? const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                  )
                : null,
            color: !isPrimaryActive && !showSignIn ? Colors.white10 : null,
            boxShadow: isPrimaryActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF4FACFE).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: isPrimaryActive
                ? () => _handlePurchase(context, provider)
                : showSignIn
                ? () => _handleGoogleSignIn(context, provider)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: provider.isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    showSignIn ? 'Sign in with Google' : 'Continue',
                    style: textTheme.titleLarge!.copyWith(
                      color: Colors.white)
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(SubscriptionProvider provider) {
    return Column(
      children: [
        Text(
          'Recurring billing. Cancel anytime.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _footerLink('Terms of Service', () => _showTermsOfService(context)),
            const Text(' • ', style: TextStyle(color: Colors.white24)),
            _footerLink('Privacy Policy', () => _showPrivacyPolicyBottomSheet(context)),
          ],
        ),
      ],
    );
  }

  Widget _footerLink(String text, Function() onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _showTermsOfService(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TermsOfService(),
    );
  }

  Future<void> _showPrivacyPolicyBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrivacyPolicy(),
    );
  }

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    final success = await provider.signInWithGoogle();
    if (!success && provider.errorMessage != null && context.mounted) {
      _showErrorDialog(context, provider.errorMessage!);
    }
  }

  Future<void> _handlePurchase(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    if (_selectedPlan == null) return;

    await provider.buySubscription(_selectedPlan!);

    if (context.mounted) {
      if (provider.errorMessage != null) {
        _showErrorDialog(context, provider.errorMessage!);
      } else if (provider.isSubscribed) {
        _showSuccessDialog(context);
      }
    }
  }

  Future<void> _handleRestore(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    final success = await provider.restorePurchases();

    if (context.mounted) {
      if (success) {
        _showSuccessDialog(
          context,
          message: 'Purchases restored successfully!',
        );
      } else if (provider.errorMessage != null) {
        _showErrorDialog(context, provider.errorMessage!);
      }
    }
  }

  Widget _removeAdsText() {
    final TextTheme  textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enjoy an Ad-Free Experience',
          style: textTheme.headlineSmall!.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Remove all ads and enjoy a smooth, distraction-free workflow. '
              'Stay focused, get more done, and experience the app at its best.',
          style: textTheme.bodyLarge!.copyWith(
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ───────────────── DIALOG METHODS ─────────────────

  void _showSuccessDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A5C),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Success!', style: TextStyle(color: Colors.white)),
        content: Text(
          message ?? 'Premium subscription activated!',
          style: const TextStyle(color: Colors.white),
        ),
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
        backgroundColor: const Color(0xFF2A3A5C),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('Sorry', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
