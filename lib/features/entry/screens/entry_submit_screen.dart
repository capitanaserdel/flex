import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

import 'package:dio/dio.dart' as dio;

class EntrySubmissionScreen extends ConsumerStatefulWidget {
  final int categoryId;

  const EntrySubmissionScreen({
    super.key,
    required this.categoryId,
  });

  @override
  ConsumerState<EntrySubmissionScreen> createState() => _EntrySubmissionScreenState();
}

class _EntrySubmissionScreenState extends ConsumerState<EntrySubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  bool _autoEnhance = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Mock category meta
  String _categoryName = 'Wankan Sallah';
  String _categoryIcon = '🛁';
  double _entryFee = 100.00;

  // Dynamic user location values
  String? _userState;
  String? _userLga;
  String? _userNeighbourhood;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoryMeta();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/profile');
      if (response.data['success'] == true) {
        final user = response.data['data']['user'];
        setState(() {
          _userState = user['state'];
          _userLga = user['lga'];
          _userNeighbourhood = user['neighbourhood'];
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  void _fetchCategoryMeta() {
    // Determine category metadata dynamically based on seed data
    switch (widget.categoryId) {
      case 2:
        _categoryName = 'Ram of the Year';
        _categoryIcon = '🐏';
        _entryFee = 200.00;
        break;
      case 3:
        _categoryName = 'Sallah Food Table';
        _categoryIcon = '🍖';
        _entryFee = 100.00;
        break;
      case 4:
        _categoryName = 'Best Haircut';
        _categoryIcon = '💈';
        _entryFee = 100.00;
        break;
      case 5:
        _categoryName = 'Cutest Kids Outfit';
        _categoryIcon = '👶';
        _entryFee = 100.00;
        break;
      case 6:
        _categoryName = 'Best Decorated Compound';
        _categoryIcon = '🏠';
        _entryFee = 200.00;
        break;
      default:
        _categoryName = 'Wankan Sallah';
        _categoryIcon = '🛁';
        _entryFee = 100.00;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitEntry() async {
    setState(() {
      _errorMessage = null;
    });

    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select or upload a Sallah photo to compete.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dio.FormData formData = dio.FormData.fromMap({
        'category_id': widget.categoryId,
        'caption': _captionController.text.trim(),
        'auto_enhance': _autoEnhance ? 1 : 0,
      });

      if (kIsWeb) {
        final bytes = await _selectedImage!.readAsBytes();
        formData.files.add(MapEntry(
          'photo',
          dio.MultipartFile.fromBytes(
            bytes,
            filename: _selectedImage!.name,
          ),
        ));
      } else {
        formData.files.add(MapEntry(
          'photo',
          await dio.MultipartFile.fromFile(
            _selectedImage!.path,
            filename: _selectedImage!.name,
          ),
        ));
      }

      final response = await ref.read(apiServiceProvider).post(
        '/entries/submit',
        data: formData,
      );

      if (response.data['success'] == true) {
        if (mounted) {
          context.go('/payment-success');
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Insufficient') || errorStr.contains('coins') || errorStr.contains('Coins') || errorStr.contains('403')) {
        if (mounted) {
          _showInsufficientCoinsDialog();
        }
      } else {
        setState(() {
          _errorMessage = errorStr;
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                'You do not have enough Sallah Coins to enter this competition.',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'This category requires ${_entryFee.toInt()} Sallah Coins.',
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Submit Entry', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(_categoryIcon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_categoryName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                          Text('Entry Fee: ₦${_entryFee.toStringAsFixed(2)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Dash Upload Box Area
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, size: 54, color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text('Choose Your Sallah Drip Photo', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Tap to select from gallery or camera', style: AppTextStyles.bodySmall),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: kIsWeb
                                    ? Image.network(
                                        _selectedImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_selectedImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: IconButton(
                                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // AI Enhancement Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI Enhancement Filter', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                  Text(
                                    'Automatically improve color balances',
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoEnhance,
                        onChanged: (value) => setState(() => _autoEnhance = value),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Caption
                TextFormField(
                  controller: _captionController,
                  maxLength: 100,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Add Caption (Optional)',
                    hintText: 'e.g. Sallah 2026 drip! 🌙✨',
                  ),
                ),
                const SizedBox(height: 12),

                // Location Pill Confirmation
                if (!_isLoadingProfile)
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.accentGold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Competing in: ${_userNeighbourhood ?? 'Naibawa'}, ${_userLga ?? 'Tarauni LGA'}, ${_userState ?? 'Kano'}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 8),
                      Text('Loading competition zone...', style: TextStyle(fontSize: 12, color: AppColors.mutedGray)),
                    ],
                  ),
                const SizedBox(height: 30),

                // Pricing Summary Table
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sallah Entry Fee'),
                          Text('₦${_entryFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Payable', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            '₦${_entryFee.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Pay & Submit Entry'),
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
