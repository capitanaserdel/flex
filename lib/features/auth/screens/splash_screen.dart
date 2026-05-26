import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _checkNavigation();
  }

  void _checkNavigation() {
    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      
      final storage = ref.read(storageServiceProvider);
      final token = storage.getToken();
      final hasSeenOnboarding = storage.getHasSeenOnboarding();

      if (token != null) {
        // Connect WebSocket and subscribe to private coin channel on auto-login
        final int? userId = storage.getUserId();
        final realtime = ref.read(realtimeServiceProvider);
        realtime.connect(jwtToken: token).then((_) {
          if (userId != null) {
            realtime.subscribeToCoins(userId);
          }
        });
        context.go('/home');
      } else if (hasSeenOnboarding) {
        context.go('/register');
      } else {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Islamic geometric pattern background decoration (Subtle grid simulation)
          Opacity(
            opacity: 0.06,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
              ),
              itemBuilder: (context, index) => const Icon(
                Icons.star_border,
                color: AppColors.accentGold,
                size: 24,
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Crescent Trophy Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentGold.withOpacity(0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🏆🌙',
                        style: TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Title
                  Text(
                    'SallahFlex',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Arabic-styled English Tagline
                  Text(
                    "Who's Leading in Your Neighbourhood?",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warmCream,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Hausa Accent translation
                  Text(
                    "Wanda Ke Gaba A Unguwarku?",
                    style: AppTextStyles.hausaAccent.copyWith(
                      color: AppColors.accentGold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
