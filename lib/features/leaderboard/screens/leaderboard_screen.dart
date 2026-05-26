import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedLevel = 'neighbourhood';
  int _selectedCategoryId = 1;

  List<dynamic> _categories = [];
  List<dynamic> _entries = [];
  bool _isLoading = false;

  // Mock my entry rank info
  int _myRank = 7;
  int _myVotes = 43;
  int _votesToNextRank = 12;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchLeaderboard();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/categories');
      if (response.data['success'] == true) {
        setState(() {
          _categories = response.data['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(apiServiceProvider).get('/entries/leaderboard', queryParameters: {
        'level': _selectedLevel,
        'category_id': _selectedCategoryId,
        'neighbourhood_id': 1, // Seed Naibawa
        'lga_id': 1,
        'state_id': 1,
      });

      if (response.data['success'] == true) {
        setState(() {
          _entries = response.data['data']['data'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Split entries into podium (top 3) and remaining list (4th+)
    final podium = _entries.take(3).toList();
    final remaining = _entries.skip(3).toList();

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Sallah leaderboards 🏆', style: AppTextStyles.displaySmall.copyWith(fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Hyperlocal Level Selector Tab
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLevelTab('Naibawa', 'neighbourhood'),
                _buildLevelTab('Tarauni LGA', 'lga'),
                _buildLevelTab('Kano', 'state'),
                _buildLevelTab('Nigeria', 'national'),
              ],
            ),
          ),

          // Categories Pills
          if (_categories.isNotEmpty)
            Container(
              height: 48,
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
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
                          _fetchLeaderboard();
                        }
                      },
                      selectedColor: AppColors.primary.withOpacity(0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No submissions in this category yet.'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            // 1. Top 3 Podium
                            if (podium.isNotEmpty) _buildPodium(podium),
                            const SizedBox(height: 24),

                            // 2. Remaining Ranked List
                            if (remaining.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: remaining.length,
                                itemBuilder: (context, index) {
                                  final entry = remaining[index];
                                  final rank = index + 4;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: ListTile(
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 30,
                                            child: Text(
                                              '#$rank',
                                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.mutedGray),
                                            ),
                                          ),
                                          CircleAvatar(
                                            backgroundImage: entry['user']['profile_photo_url'] != null
                                                ? NetworkImage(entry['user']['profile_photo_url'])
                                                : null,
                                          ),
                                        ],
                                      ),
                                      title: Text(entry['user']['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(entry['neighbourhood']['name']),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${entry['vote_count']} votes',
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.favorite, color: AppColors.primary, size: 16),
                                        ],
                                      ),
                                      onTap: () => context.push('/entry/${entry['id']}'),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 80), // My Rank Bar space
                          ],
                        ),
                      ),
          ),
        ],
      ),
      
      // Sticky My Rank Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.richBrown,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your standing: #$_myRank in Naibawa 🏆',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$_myVotes votes | Need $_votesToNextRank more to reach #${_myRank - 1}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.warmCream),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Open vote bundle purchase trigger
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Get more votes by sharing your card with peers!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.richBrown,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Get Votes 🗳️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelTab(String label, String value) {
    final isSelected = _selectedLevel == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedLevel = value;
          });
          _fetchLeaderboard();
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.mutedGray,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPodium(List<dynamic> top3) {
    // podium list: 2nd place is index 1, 1st place is index 0, 3rd place is index 2
    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place Column
          if (second != null) _buildPodiumColumn(second, 2, 100, Colors.grey),

          // 1st Place Column (Taller center)
          _buildPodiumColumn(first, 1, 130, AppColors.accentGold, isWinner: true),

          // 3rd Place Column
          if (third != null) _buildPodiumColumn(third, 3, 80, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(dynamic entry, int rank, double height, Color crownColor, {bool isWinner = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isWinner)
          const Text('👑', style: TextStyle(fontSize: 26))
        else
          const SizedBox(height: 26),
        const SizedBox(height: 8),

        // circular profile photo
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: crownColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: crownColor.withOpacity(0.2),
                blurRadius: 10,
              )
            ],
          ),
          child: ClipOval(
            child: entry['user']['profile_photo_url'] != null
                ? Image.network(entry['user']['profile_photo_url'], fit: BoxFit.cover)
                : const Icon(Icons.person, size: 40),
          ),
        ),
        const SizedBox(height: 12),

        // Username
        Text(
          entry['user']['name'].toString().split(' ')[0],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          '${entry['vote_count']} votes',
          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Podium Pillar
        Container(
          width: 85,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: AppTextStyles.leaderboardRank.copyWith(color: Colors.white, fontSize: 24),
            ),
          ),
        ),
      ],
    );
  }
}
