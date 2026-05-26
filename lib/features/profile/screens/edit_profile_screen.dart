import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _notifyVote = true;
  bool _notifyRank = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() {
    final storage = ref.read(storageServiceProvider);
    _nameController.text = storage.getUserName() ?? 'Aisha Musa';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ref.read(apiServiceProvider).put('/profile/update', data: {
        'name': _nameController.text.trim(),
      });

      if (response.data['success'] == true) {
        final storage = ref.read(storageServiceProvider);
        await storage.saveUserSession(
          name: _nameController.text.trim(),
          phone: storage.getUserPhone() ?? '',
          isVerified: storage.isUserVerified(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully! ✅'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          context.go('/profile');
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    final storage = ref.read(storageServiceProvider);
    await storage.clearAll();
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account? ⚠️'),
        content: const Text(
          'Are you sure you want to permanently delete your SallahFlex account? This will void all entries, votes, and historical records. This action is irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(apiServiceProvider).delete('/profile/delete-account');
        await ref.read(storageServiceProvider).clearAll();
        if (mounted) {
          context.go('/register');
        }
      } catch (_) {}
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Edit Settings', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal details', style: AppTextStyles.displaySmall.copyWith(fontSize: 18)),
                const SizedBox(height: 16),

                // Name controller
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g. Aisha Musa',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Text('Notification Preferences', style: AppTextStyles.displaySmall.copyWith(fontSize: 18)),
                const SizedBox(height: 12),

                // Toggles
                SwitchListTile(
                  title: const Text('New Vote Received'),
                  subtitle: const Text("Receive alerts when someone votes for your Sallah drip"),
                  value: _notifyVote,
                  onChanged: (value) => setState(() => _notifyVote = value),
                  activeColor: AppColors.primary,
                ),
                SwitchListTile(
                  title: const Text('Rank Standings Change'),
                  subtitle: const Text("Receive alerts when your neighbourhood rank drops or hits #1"),
                  value: _notifyRank,
                  onChanged: (value) => setState(() => _notifyRank = value),
                  activeColor: AppColors.primary,
                ),
                const SizedBox(height: 35),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Settings'),
                  ),
                ),
                const SizedBox(height: 20),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.exit_to_app, color: AppColors.errorRed),
                    label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      side: const BorderSide(color: AppColors.errorRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Delete account link
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text(
                      'Permanently Delete Account',
                      style: TextStyle(
                        color: AppColors.errorRed,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
