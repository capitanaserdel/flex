import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';
import '../widgets/status_viewer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedLevel = 'neighbourhood'; // neighbourhood, lga, state, national
  int _selectedCategoryId = 1;
  String _currentNeighbourhoodName = 'Naibawa';
  int _coinsBalance = 500;

  List<dynamic> _categories = [];
  List<dynamic> _entries = [];
  List<dynamic> _myEntries = [];
  bool _isLoading = false;

  // Countdown timer parameters
  late Timer _countdownTimer;
  Duration _timeLeft = const Duration(days: 5, hours: 14, minutes: 22);

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchMyEntries();
    _fetchFeed();
    _fetchCoinsBalance();
    _startCountdown();
  }

  Future<void> _fetchCoinsBalance() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/votes/balance');
      if (response.data['success'] == true && mounted) {
        setState(() {
          _coinsBalance = response.data['data']['paid_votes_remaining'];
        });
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft.inMinutes > 0) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(minutes: 1);
        });
      } else {
        _countdownTimer.cancel();
      }
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/categories');
      if (response.data['success'] == true && mounted) {
        setState(() {
          _categories = response.data['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyEntries() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/entries/my');
      if (response.data['success'] == true && mounted) {
        setState(() {
          _myEntries = response.data['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchFeed() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ref.read(apiServiceProvider).get('/entries/leaderboard', queryParameters: {
        'level': _selectedLevel,
        'category_id': _selectedCategoryId,
        'neighbourhood_id': 1, // Seed neighbourhood Naibawa
        'lga_id': 1,
        'state_id': 1,
      });
      if (response.data['success'] == true && mounted) {
        setState(() {
          _entries = response.data['data']['data'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchCategories(),
      _fetchMyEntries(),
      _fetchFeed(),
      _fetchCoinsBalance(),
    ]);
  }

  Future<void> _castVote(int entryId, int index) async {
    try {
      final response = await ref.read(apiServiceProvider).post('/votes/cast', data: {
        'entry_id': entryId,
        'level': _selectedLevel,
      });

      if (response.data['success'] == true) {
        // Increment vote count locally
        setState(() {
          _entries[index]['vote_count'] = response.data['data']['new_vote_count'];
          _coinsBalance = response.data['data']['paid_votes_remaining'];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vote cast successfully! 💛'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      // If vote balance/coins exhausted, trigger coin bundles purchase bottom sheet
      if (e.toString().contains('exhausted') || e.toString().contains('403')) {
        _showVotePacksSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showVotePacksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.softWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Top Up Your Sallah Coins 🪙",
              style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Get Sallah coins to vote and support the best Eid outfits in your community!',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
            ),
            const SizedBox(height: 20),
            
            _buildVotePackItem('100 Coins 🪙', '₦100', 1),
            _buildVotePackItem('500 Coins 🪙', '₦500', 2, isPopular: true),
            _buildVotePackItem('1000 Coins 🪙', '₦1000', 3, isBestValue: true),
          ],
        ),
      ),
    );
  }

  Widget _buildVotePackItem(String title, String price, int packId, {bool isPopular = false, bool isBestValue = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular || isBestValue ? AppColors.accentGold : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  if (isPopular)
                    Text('Most Popular 🔥', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  if (isBestValue)
                    Text('Best Value 🌟', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              double amount = 100.0;
              if (packId == 2) amount = 500.0;
              if (packId == 3) amount = 1000.0;
              
              await _purchaseVotePack(packId, amount);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: AppColors.primary,
            ),
            child: Text(price, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseVotePack(int packId, double amount) async {
    try {
      final response = await ref.read(apiServiceProvider).post('/payments/initiate', data: {
        'amount': amount,
        'type': 'vote_pack',
        'metadata': {'pack_id': packId},
      });

      if (response.data['success'] == true) {
        final checkoutUrl = response.data['checkout_url'];
        final transactionRef = response.data['transaction_ref'];

        final Uri url = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch payment screen: $checkoutUrl';
        }

        if (mounted) {
          _showVotePackVerificationDialog(packId, transactionRef);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initiation failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showVotePackVerificationDialog(int packId, String transactionRef) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isVerifying = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.softWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Text('Verify Coin Purchase', style: AppTextStyles.displaySmall),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete payment in your browser tab.',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Once done, tap "Verify Payment" to activate your Sallah coins.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedGray),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      dialogError!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (isVerifying) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel', style: TextStyle(color: AppColors.errorRed)),
                ),
                ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    setDialogState(() {
                      isVerifying = true;
                      dialogError = null;
                    });

                    try {
                      final verifyResponse = await ref.read(apiServiceProvider).post('/votes/purchase', data: {
                        'pack_id': packId,
                        'payment_ref': transactionRef,
                      });

                      if (verifyResponse.data['success'] == true) {
                        if (context.mounted) {
                          setState(() {
                            _coinsBalance = verifyResponse.data['data']['paid_votes_remaining'];
                          });
                          Navigator.of(context).pop(); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Coins activated successfully! Balance: ${verifyResponse.data['data']['paid_votes_remaining']} 🪙'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      setDialogState(() {
                        isVerifying = false;
                        dialogError = 'Verification failed. Please ensure payment completed successfully.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Verify Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCategorySelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.softWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Your Category 🌙', style: AppTextStyles.displaySmall),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Card(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/entry-submit', extra: cat['id']);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['icon'], style: const TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          Text(cat['name_en'], style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text('₦${cat['entry_fee']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Text('Sallah', style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary, fontSize: 22)),
            Text('Flex', style: AppTextStyles.displaySmall.copyWith(color: AppColors.accentGold, fontSize: 22)),
          ],
        ),
        actions: [
          // Coins Pill
          GestureDetector(
            onTap: _showVotePacksSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🪙 ', style: TextStyle(fontSize: 14)),
                  Text(
                    '$_coinsBalance',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Location Pill
          ActionChip(
            label: Text('📍 $_currentNeighbourhoodName'),
            onPressed: () {},
            backgroundColor: AppColors.warmCream.withOpacity(0.4),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.darkText),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.accentGold,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner Countdown
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eid Entries Close In: 🌙',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$days Days $hours Hours $minutes Minutes',
                    style: AppTextStyles.displayMedium.copyWith(color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _showCategorySelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      foregroundColor: AppColors.darkText,
                      elevation: 0,
                    ),
                    child: const Text('Upload Your Photo Now! ✨'),
                  ),
                ],
              ),
            ),

            // Sallah Statuses Row (WhatsApp-like Stories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Sallah Statuses 🌙', style: AppTextStyles.displaySmall.copyWith(fontSize: 18)),
            ),
            Container(
              height: 105,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 1 + _entries.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // My Status
                    final hasEntry = _myEntries.isNotEmpty;
                    final photoUrl = hasEntry ? _myEntries[0]['photo_url'] : null;
                    return GestureDetector(
                      onTap: () {
                        if (hasEntry) {
                          // View status starting with My Status
                          final allStatuses = [..._myEntries, ..._entries];
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (context, _, __) => StatusViewer(
                                entries: allStatuses,
                                initialIndex: 0,
                                level: _selectedLevel,
                              ),
                              transitionsBuilder: (context, animation, _, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          ).then((_) {
                            _fetchMyEntries();
                            _fetchFeed();
                          });
                        } else {
                          // Upload new status
                          _showCategorySelection();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hasEntry ? AppColors.accentGold : AppColors.mutedGray.withOpacity(0.3),
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.warmCream,
                                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                    child: photoUrl == null
                                        ? const Icon(Icons.person, color: AppColors.mutedGray, size: 28)
                                        : null,
                                  ),
                                ),
                                if (!hasEntry)
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'My Status',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Feed user statuses
                  final entry = _entries[index - 1];
                  final isBoosted = entry['is_boosted'] == true;
                  final userPhoto = entry['user']['profile_photo_url'] ?? entry['photo_url'];

                  return GestureDetector(
                    onTap: () {
                      final allStatuses = [..._myEntries, ..._entries];
                      final startIndex = _myEntries.length + (index - 1);
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (context, _, __) => StatusViewer(
                            entries: allStatuses,
                            initialIndex: startIndex,
                            level: _selectedLevel,
                          ),
                          transitionsBuilder: (context, animation, _, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                        ),
                      ).then((_) {
                        _fetchMyEntries();
                        _fetchFeed();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isBoosted ? AppColors.accentGold : AppColors.primary,
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.warmCream,
                              backgroundImage: NetworkImage(userPhoto),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 65,
                            child: Text(
                              entry['user']['name'].toString().split(' ')[0],
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w500, 
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Active Entries Section
            if (_myEntries.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('My Sallah Entries 🛁', style: AppTextStyles.displaySmall.copyWith(fontSize: 18)),
              ),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _myEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _myEntries[index];
                    return GestureDetector(
                      onTap: () {
                        // Launch status viewer starting with this clicked entry
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (context, _, __) => StatusViewer(
                              entries: _myEntries,
                              initialIndex: index,
                              level: _selectedLevel,
                            ),
                            transitionsBuilder: (context, animation, _, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        ).then((_) {
                          _fetchMyEntries();
                          _fetchFeed();
                        });
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(entry['photo_url'], width: 50, height: 50, fit: coverFitHelper()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(entry['category']['name_en'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.how_to_vote, size: 12, color: AppColors.primary),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${entry['vote_count']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.visibility, size: 12, color: AppColors.mutedGray),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${entry['view_count'] ?? 0}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.mutedGray),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Tabs for levels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLevelTab('Street', 'neighbourhood'),
                  _buildLevelTab('LGA', 'lga'),
                  _buildLevelTab('State', 'state'),
                  _buildLevelTab('Nigeria', 'national'),
                ],
              ),
            ),

            // Category list filter pills
            if (_categories.isNotEmpty)
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategoryId == cat['id'];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text('${cat['icon']} ${cat['name_en']}'),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategoryId = cat['id'];
                            });
                            _fetchFeed();
                          }
                        },
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        checkmarkColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),

            // Feed of entry cards
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_entries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No submissions in this category yet. Be the first! 🌙'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final isTop3 = index < 3;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: entry['user']['profile_photo_url'] != null
                                ? NetworkImage(entry['user']['profile_photo_url'])
                                : null,
                            child: entry['user']['profile_photo_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Text(entry['user']['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (entry['is_boosted'] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.accentGold),
                                  ),
                                  child: Text('BOOSTED', style: AppTextStyles.bodySmall.copyWith(color: AppColors.richBrown, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(entry['neighbourhood']['name']),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isTop3 ? AppColors.accentGold.withOpacity(0.15) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: AppTextStyles.leaderboardRank.copyWith(
                                color: isTop3 ? AppColors.richBrown : AppColors.mutedGray,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        // Contest Photo
                        GestureDetector(
                          onTap: () => context.push('/entry/${entry['id']}'),
                          child: Container(
                            height: 250,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(entry['photo_url']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        // Caption & Vote Button Row
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (entry['caption'] != null)
                                      Text(
                                        entry['caption'],
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${entry['vote_count']} votes',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•',
                                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedGray),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.visibility, size: 14, color: AppColors.mutedGray),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${entry['view_count'] ?? 0} views',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.mutedGray,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _castVote(entry['id'], index),
                                icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
                                label: const Text('Vote'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 80), // Padding for Floating button
          ],
        ),
      ),
    ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCategorySelection,
        backgroundColor: AppColors.accentGold,
        foregroundColor: AppColors.richBrown,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  BoxFit coverFitHelper() {
    return BoxFit.cover;
  }

  Widget _buildLevelTab(String label, String value) {
    final isSelected = _selectedLevel == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = value;
        });
        _fetchFeed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.mutedGray,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: AppColors.primary),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined, color: AppColors.mutedGray),
              onPressed: () => context.push('/leaderboard'),
            ),
            const SizedBox(width: 48), // Raised Button gap
            IconButton(
              icon: const Icon(Icons.history_edu, color: AppColors.mutedGray),
              onPressed: () => context.push('/hall-of-fame'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: AppColors.mutedGray),
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}
