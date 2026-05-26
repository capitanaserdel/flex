import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PaymentFailureScreen extends StatelessWidget {
  const PaymentFailureScreen({super.key});

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
              // Fail Cross Ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.errorRed, width: 3),
                ),
                child: const Center(
                  child: Text(
                    '❌⚠️',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Payment Failed',
                style: AppTextStyles.displayMedium.copyWith(color: AppColors.errorRed),
              ),
              const SizedBox(height: 12),
              Text(
                'The Paystack transaction was declined or cancelled. Please verify your balance and try the submission again.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              const Spacer(),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                  ),
                  child: const Text('Return to Feed'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Secondary CTA
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support email copied: support@sallahflex.ng'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  child: const Text(
                    'Contact SallahFlex Support',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
