import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  dynamic _profileData;
  List<dynamic> _badges = [];
  bool _isLoading = true;

  // WebSocket subscription for live coin balance
  StreamSubscription<Map<String, dynamic>>? _coinSub;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchBadges();
    _subscribeToCoinBalance();
  }

  @override
  void dispose() {
    _coinSub?.cancel();
    super.dispose();
  }

  void _subscribeToCoinBalance() {
    final realtime = ref.read(realtimeServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final userId = storage.getUserId();
    if (userId != null) {
      realtime.subscribeToCoins(userId);
    }
    _coinSub = realtime.coinStream.listen((data) {
      if (!mounted) return;
      final newBalance = data['new_balance'];
      if (newBalance != null && _profileData != null) {
        setState(() {
          // Update the coin balance in the profile stats map so the UI reflects instantly
          _profileData['stats']['coin_balance'] = newBalance;
        });
      }
    });
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/profile');
      if (response.data['success'] == true) {
        setState(() {
          _profileData = response.data['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBadges() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/badges/my');
      if (response.data['success'] == true) {
        setState(() {
          _badges = response.data['data'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _profileData?['user'];
    final stats = _profileData?['stats'];

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('My Profile', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.darkText),
            onPressed: () => context.push('/edit-profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar profile image & name card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.primary,
                    backgroundImage: user?['profile_photo_url'] != null
                        ? NetworkImage(user['profile_photo_url'])
                        : null,
                    child: user?['profile_photo_url'] == null
                        ? const Icon(Icons.person, size: 54, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?['name'] ?? 'Aisha Musa',
                    style: AppTextStyles.displaySmall.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.accentGold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${user?['neighbourhood'] ?? 'Naibawa'}, ${user?['lga'] ?? 'Tarauni LGA'}',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Joined: ${user?['created_at'] ?? 'May 2026'}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙 ', style: TextStyle(fontSize: 16)),
                        Text(
                          '${user?['coins_balance'] ?? 0} Sallah Coins',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Statistics Row Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    stats?['total_entries']?.toString() ?? '1',
                    'Entries',
                  ),
                  Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                  _buildStatItem(
                    stats?['total_votes_received']?.toString() ?? '234',
                    'Votes Got',
                  ),
                  Container(width: 1, height: 40, color: const Color(0xFFEEEEEE)),
                  _buildStatItem(
                    stats?['best_rank'] ?? '#2',
                    'Best Rank',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Gamified Badge List Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My Sallah Badges 👑', style: AppTextStyles.displaySmall.copyWith(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 125,
              margin: const EdgeInsets.only(bottom: 24),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildBadgeCard(
                    '👑',
                    'Sallah Royalty',
                    _badges.any((b) => b['badge']?['name'] == 'Sallah Royalty')
                        ? 'Unlocked'
                        : 'Locked',
                    isLocked: !_badges.any((b) => b['badge']?['name'] == 'Sallah Royalty'),
                  ),
                  _buildBadgeCard('🏆', 'Naibawa Champion', 'Unlocked'),
                  _buildBadgeCard('🐏', 'Ram Master', 'Locked', isLocked: true),
                  _buildBadgeCard('🧼', 'Eid Veteran', 'Locked', isLocked: true),
                ],
              ),
            ),

            // CTA Crown purchase royalty badge
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sallah Royalty Badge',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.richBrown),
                        ),
                        Text(
                          'Add a golden crown decoration to your profile for only ₦200!',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.richBrown.withOpacity(0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await _purchaseCrown();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.richBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Buy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseCrown() async {
    try {
      final response = await ref.read(apiServiceProvider).post('/badges/purchase-royalty');
      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Congratulations! You are now Sallah Royalty! 👑'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          _fetchBadges();
          _fetchProfile(); // reload profile so coins_balance is updated in the UI!
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Insufficient') || errorStr.contains('coins') || errorStr.contains('Coins') || errorStr.contains('403')) {
        if (mounted) {
          _showInsufficientCoinsDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.softWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text('Insufficient Coins', style: AppTextStyles.displaySmall),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You do not have enough Sallah Coins to purchase Sallah Royalty.',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'The crown cosmetic costs 200 Sallah Coins.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedGray),
              ),
              const SizedBox(height: 10),
              Text(
                'Please top up your Sallah Coins balance first.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.errorRed)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Go to Home to Top Up'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary, fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(String icon, String title, String status, {bool isLocked = false}) {
    return Opacity(
      opacity: isLocked ? 0.4 : 1.0,
      child: Card(
        color: Colors.white,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(status, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
