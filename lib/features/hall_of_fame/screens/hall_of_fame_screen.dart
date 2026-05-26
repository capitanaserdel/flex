import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class HallOfFameScreen extends ConsumerStatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  ConsumerState<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends ConsumerState<HallOfFameScreen> {
  int _selectedYear = 2026;
  int _selectedCategoryId = 1;

  List<dynamic> _categories = [];
  List<dynamic> _champions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchChampions();
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

  Future<void> _fetchChampions() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(apiServiceProvider).get('/hall-of-fame', queryParameters: {
        'category_id': _selectedCategoryId,
      });

      if (response.data['success'] == true) {
        setState(() {
          _champions = response.data['data'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Hall of Fame 👑', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Year Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildYearTab(2026),
                _buildYearTab(2025),
                _buildYearTab(2024),
              ],
            ),
          ),

          // Categories horizontal list
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
                          _fetchChampions();
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
                : _champions.isEmpty
                    ? const Center(
                        child: Text(
                          'No historical champions seeded yet for this category.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _champions.length,
                        itemBuilder: (context, index) {
                          final champ = _champions[index];
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.accentGold, width: 2),
                            ),
                            child: InkWell(
                              onTap: () => context.push('/entry/${champ['id']}?level=national'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                      child: Image.network(
                                        champ['photo_url'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('👑', style: TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                champ['user']['name'].toString().split(' ')[0],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          champ['neighbourhood']['name'],
                                          style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Champion $_selectedYear',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }

  Widget _buildYearTab(int year) {
    final isSelected = _selectedYear == year;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedYear = year;
        });
        _fetchChampions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          year.toString(),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.mutedGray,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
