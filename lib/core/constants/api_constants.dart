import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    // Connect to Mac host IP over local Wi-Fi network (current IP is 192.168.1.166)
    return 'http://192.168.1.166:8000/api';
  }

  // Auth routes
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Locations
  static const String states = '/locations/states';
  static const String lgas = '/locations/lgas';
  static const String neighbourhoods = '/locations/neighbourhoods';

  // Categories
  static const String categories = '/categories';

  // Entries
  static const String submitEntry = '/entries/submit';
  static const String myEntries = '/entries/my';
  static const String leaderboard = '/entries/leaderboard';
  static const String entryDetail = '/entries'; // suffix with /{id}
  static const String boostEntry = '/entries'; // suffix with /{id}/boost
  static const String reportEntry = '/entries'; // suffix with /{id}/report

  // Voting
  static const String castVote = '/votes/cast';
  static const String voteBalance = '/votes/balance';
  static const String purchaseVotes = '/votes/purchase';

  // Profile
  static const String profile = '/profile';
  static const String updateProfile = '/profile/update';
  static const String changePassword = '/profile/change-password';
  static const String deleteAccount = '/profile/delete-account';

  // Badges
  static const String myBadges = '/badges/my';
  static const String allBadges = '/badges/all';
  static const String purchaseRoyalty = '/badges/purchase-royalty';

  // Hall of Fame
  static const String hallOfFame = '/hall-of-fame';

  // Notifications
  static const String notifications = '/notifications';
  static const String markNotificationsRead = '/notifications/mark-read';
}
