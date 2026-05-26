import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated checked ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.successGreen, width: 3),
                ),
                child: const Center(
                  child: Text(
                    '🎉✅',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Payment Successful!',
                style: AppTextStyles.displayMedium.copyWith(color: AppColors.successGreen),
              ),
              const SizedBox(height: 12),
              Text(
                'Your SallahFlex entry has been successfully registered and published! Share your teaser card to collect votes immediately.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Mock invoice summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Payment Reference', 'SF-2026-LIVE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
                    const Divider(height: 24),
                    _buildSummaryRow('Monetary Drip Fee', '₦100.00'),
                    const Divider(height: 24),
                    _buildSummaryRow('Gate Processor', 'Paystack Gateway'),
                  ],
                ),
              ),

              const Spacer(),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('View Live Feed'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Secondary CTA
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generative Teaser Copied to Clipboard! 🌙'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Share Teaser Card 👑', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mutedGray, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
