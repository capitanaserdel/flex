import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final int entryId;
  final String level;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.level = 'neighbourhood',
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  dynamic _entry;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showChallenge = false;
  int _userCoins = 500;

  // WebSocket stream subscriptions
  StreamSubscription<Map<String, dynamic>>? _voteSub;
  StreamSubscription<Map<String, dynamic>>? _coinSub;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _fetchCoinsBalance();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _voteSub?.cancel();
    _coinSub?.cancel();
    // Unsubscribe from the entry-specific WS channel
    ref.read(realtimeServiceProvider).unsubscribeFromEntry(widget.entryId);
    super.dispose();
  }

  void _subscribeToRealtime() {
    final realtime = ref.read(realtimeServiceProvider);
    final storage = ref.read(storageServiceProvider);

    // Subscribe to live vote count updates for this entry
    realtime.subscribeToEntry(widget.entryId);
    _voteSub = realtime.voteStream.listen((data) {
      if (!mounted) return;
      final entryId = data['entry_id'];
      if (entryId != null && entryId.toString() == widget.entryId.toString()) {
        _fetchDetail(showLoading: false);
      }
    });

    // Subscribe to live coin balance (only fires for the logged-in user)
    final userId = storage.getUserId();
    if (userId != null) {
      realtime.subscribeToCoins(userId);
    }
    _coinSub = realtime.coinStream.listen((data) {
      if (!mounted) return;
      final newBalance = data['new_balance'];
      if (newBalance != null) {
        setState(() {
          _userCoins = newBalance as int;
        });
      }
    });
  }

  Future<void> _fetchCoinsBalance() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/votes/balance');
      if (response.data['success'] == true) {
        setState(() {
          _userCoins = response.data['data']['paid_votes_remaining'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDetail({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await ref.read(apiServiceProvider).get('/entries/${widget.entryId}');
      if (response.data['success'] == true) {
        setState(() {
          _entry = response.data['data'];
        });
      }
    } catch (e) {
      if (showLoading) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _vote(String level) async {
    try {
      final response = await ref.read(apiServiceProvider).post('/votes/cast', data: {
        'entry_id': widget.entryId,
        'level': level,
      });

      if (response.data['success'] == true) {
        // The REST response also updates state immediately as a fallback
        // (WebSocket broadcast will also arrive and update via _voteSub)
        setState(() {
          _entry['vote_count'] = response.data['data']['new_vote_count'];
          _userCoins = response.data['data']['paid_votes_remaining'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vote cast at ${level.toUpperCase()} level! 💛'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('location_error') || msg.contains('location')) {
        // Location-based restriction
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location restriction: You cannot vote at the $level level for this entry.'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (msg.contains('exhausted') || msg.contains('403')) {
        _showCoinPurchaseSheet();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  void _showVotingLevelSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.softWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Text(
                          'Select Voting Level',
                          style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$_userCoins Coins 🪙',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Support ${_entry['user']['name']} in their hyperlocal Eid categories!',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
                ),
                const SizedBox(height: 20),
                _buildLevelVoteOption('town', 'Town (Neighbourhood)', '50 Coins 🪙', 'Vote in ${_entry['neighbourhood']['name']}'),
                _buildLevelVoteOption('lga', 'LGA (Local Govt)', '150 Coins 🪙', 'Vote in ${_entry['lga'] != null ? _entry['lga']['name'] : 'LGA'}'),
                _buildLevelVoteOption('state', 'State level', '200 Coins 🪙', 'Vote in ${_entry['state'] != null ? _entry['state']['name'] : 'State'}'),
                _buildLevelVoteOption('national', 'National level', '300 Coins 🪙', 'Vote across Nigeria 🇳🇬'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelVoteOption(String levelCode, String title, String priceText, String description) {
    final String normalizedActiveLevel;
    if (widget.level == 'neighbourhood') {
      normalizedActiveLevel = 'town';
    } else if (widget.level == 'nation') {
      normalizedActiveLevel = 'national';
    } else {
      normalizedActiveLevel = widget.level;
    }

    final bool isEnabled = levelCode == normalizedActiveLevel;

    final String feedName = switch (levelCode) {
      'town' => 'Street',
      'lga' => 'LGA',
      'state' => 'State',
      'national' => 'Nigeria',
      _ => '',
    };

    final String displayDescription = isEnabled 
        ? description 
        : '$description (Switch to $feedName feed)';

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isEnabled ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
            )
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const CircleAvatar(
            backgroundColor: AppColors.warmCream,
            child: Text('🗳️', style: TextStyle(fontSize: 20)),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEnabled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active Feed',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              displayDescription, 
              style: AppTextStyles.bodySmall.copyWith(
                color: isEnabled ? AppColors.mutedGray : AppColors.errorRed.withOpacity(0.7),
                fontWeight: isEnabled ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          trailing: ElevatedButton(
            onPressed: isEnabled ? () {
              Navigator.pop(context);
              _vote(levelCode);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled ? AppColors.primary : Colors.grey.shade300,
              foregroundColor: isEnabled ? Colors.white : Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: isEnabled ? 2 : 0,
            ),
            child: Text(priceText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _showCoinPurchaseSheet() {
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
              'Get Sallah coins to vote and support this Eid outfit in the competition!',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
            ),
            const SizedBox(height: 20),
            
            _buildCoinPackItem('100 Coins 🪙', '₦100', 1),
            _buildCoinPackItem('500 Coins 🪙', '₦500', 2, isPopular: true),
            _buildCoinPackItem('1000 Coins 🪙', '₦1000', 3, isBestValue: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinPackItem(String title, String price, int packId, {bool isPopular = false, bool isBestValue = false}) {
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
              
              await _purchaseCoins(packId, amount);
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

  Future<void> _purchaseCoins(int packId, double amount) async {
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
          _showCoinsVerificationDialog(packId, transactionRef);
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

  void _showCoinsVerificationDialog(int packId, String transactionRef) {
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
                            _userCoins = verifyResponse.data['data']['paid_votes_remaining'];
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: Center(child: Text(_errorMessage ?? 'Entry not found')),
      );
    }

    final String dynamicRankText;
    final activeLevel = widget.level;
    if (activeLevel == 'neighbourhood' || activeLevel == 'town') {
      final rank = _entry['neighbourhood_rank'] ?? 2;
      final name = _entry['neighbourhood'] != null ? _entry['neighbourhood']['name'] : 'Naibawa';
      dynamicRankText = '#$rank in $name 🏆';
    } else if (activeLevel == 'lga') {
      final rank = _entry['lga_rank'] ?? 2;
      final name = _entry['lga'] != null ? _entry['lga']['name'] : 'LGA';
      dynamicRankText = '#$rank in $name 🏆';
    } else if (activeLevel == 'state') {
      final rank = _entry['state_rank'] ?? 2;
      final name = _entry['state'] != null ? _entry['state']['name'] : 'State';
      dynamicRankText = '#$rank in $name State 🏆';
    } else {
      final rank = _entry['national_rank'] ?? 2;
      dynamicRankText = '#$rank in Nigeria 🏆';
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // Collapsible Image Header
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.0,
                child: Image.network(
                  _entry['photo_url'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),

          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contestant details & Rank badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: _entry['user']['profile_photo_url'] != null
                                ? NetworkImage(_entry['user']['profile_photo_url'])
                                : null,
                            child: _entry['user']['profile_photo_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _entry['user']['name'],
                                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _entry['neighbourhood']['name'],
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.accentGold),
                        ),
                        child: Text(
                          dynamicRankText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.richBrown,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Category badge & caption
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_entry['category']['icon']} ${_entry['category']['name_en']}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_entry['caption'] != null)
                    Text(
                      _entry['caption'],
                      style: AppTextStyles.bodyLarge,
                    ),
                  const SizedBox(height: 24),

                  // Dynamic Votes Card
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${_entry['vote_count']} Votes 🗳️',
                                    style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary, fontSize: 20),
                                  ),
                                  Text(
                                    '•',
                                    style: TextStyle(color: AppColors.mutedGray.withOpacity(0.5), fontSize: 16),
                                  ),
                                  Text(
                                    '${_entry['view_count'] ?? 0} Views 👁️',
                                    style: AppTextStyles.displaySmall.copyWith(color: AppColors.mutedGray, fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('Hyperlocal coin-based votes', style: TextStyle(fontSize: 11, color: AppColors.mutedGray)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showVotingLevelSelector,
                          icon: const Icon(Icons.favorite, color: Colors.white),
                          label: const Text('Vote Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Head to head challenge simulation
                  if (_showChallenge)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warmCream.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentGold.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('You', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('43 Votes', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.richBrown)),
                              Column(
                                children: [
                                  Text(_entry['user']['name'].toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${_entry['vote_count']} Votes', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('🔥 24-hour challenge ends in 18h 42m', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showChallenge = true;
                          });
                        },
                        icon: const Icon(Icons.flash_on, color: AppColors.accentGold),
                        label: const Text('Challenge for #1 Rank'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.richBrown,
                          side: const BorderSide(color: AppColors.accentGold, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  
                  // Share trigger
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Generate sharing parameters
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Generating Share Card... 🌙'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share Drip Card'),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
