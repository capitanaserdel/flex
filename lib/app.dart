import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';

// Import screens (which we will build sequentially)
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/entry/screens/entry_submit_screen.dart';
import 'features/entry/screens/entry_detail_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/hall_of_fame/screens/hall_of_fame_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/payments/screens/payment_success_screen.dart';
import 'features/payments/screens/payment_failure_screen.dart';

class SallahFlexApp extends StatelessWidget {
  const SallahFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return OtpScreen(
              phone: extra?['phone'] ?? '',
              type: extra?['type'] ?? 'register',
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/entry-submit',
          builder: (context, state) {
            final categoryId = state.extra as int? ?? 1;
            return EntrySubmissionScreen(categoryId: categoryId);
          },
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 1;
            return EntryDetailScreen(entryId: id);
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/hall-of-fame',
          builder: (context, state) => const HallOfFameScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/payment-success',
          builder: (context, state) => const PaymentSuccessScreen(),
        ),
        GoRoute(
          path: '/payment-failure',
          builder: (context, state) => const PaymentFailureScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'SallahFlex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
