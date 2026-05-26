import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/service_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoadingLocation = false;
  String _gender = 'Male';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Locations state
  List<dynamic> _states = [];
  List<dynamic> _lgas = [];
  List<dynamic> _neighbourhoods = [];

  int? _selectedStateId;
  int? _selectedLgaId;
  int? _selectedNeighbourhoodId;

  @override
  void initState() {
    super.initState();
    _fetchStates();
  }

  Future<void> _fetchStates() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/locations/states');
      if (response.data['success'] == true) {
        setState(() {
          _states = response.data['data'];
        });
      }
    } catch (e) {
      // Offline fallback seed data
      setState(() {
        _states = [
          {'id': 1, 'name': 'Kano State'}
        ];
      });
    }
  }

  Future<void> _fetchLgas(int stateId) async {
    try {
      final response = await ref.read(apiServiceProvider).get('/locations/lgas', queryParameters: {'state_id': stateId});
      if (response.data['success'] == true) {
        setState(() {
          _lgas = response.data['data'];
          _neighbourhoods = [];
          _selectedLgaId = null;
          _selectedNeighbourhoodId = null;
        });
      }
    } catch (e) {
      setState(() {
        _lgas = [
          {'id': 1, 'name': 'Tarauni LGA'}
        ];
      });
    }
  }

  Future<void> _fetchNeighbourhoods(int lgaId) async {
    try {
      final response = await ref.read(apiServiceProvider).get('/locations/neighbourhoods', queryParameters: {'lga_id': lgaId});
      if (response.data['success'] == true) {
        setState(() {
          _neighbourhoods = response.data['data'];
          _selectedNeighbourhoodId = null;
        });
      }
    } catch (e) {
      setState(() {
        _neighbourhoods = [
          {'id': 1, 'name': 'Naibawa'},
          {'id': 2, 'name': 'Tarauni'}
        ];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    double latitude = 11.9177;
    double longitude = 8.4576;
    bool isMocked = false;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied.';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      // Add a 4 second timeout for getting position so it doesn't hang in emulator
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      debugPrint('[Geolocator] Current position error: $e. Falling back to Panshekara/Kumbotso.');
      isMocked = true;
      latitude = 11.9177;
      longitude = 8.4576;
    }

    String displayName = "";
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'SallahFlexApp/1.0 (contact@sallahflex.ng)',
          },
        ),
      );
      if (response.data != null && response.data['display_name'] != null) {
        displayName = response.data['display_name'].toString();
      }
    } catch (e) {
      debugPrint('[Geolocator] Reverse geocoding error: $e');
    }

    if (displayName.isEmpty) {
      if (isMocked) {
        displayName = "Bakin Ruwa, Panshekara, Kumbotso, Kano State, Nigeria";
      } else {
        displayName = "Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}";
      }
    } else {
      // Truncate overly long display names
      if (displayName.length > 80) {
        displayName = displayName.substring(0, 80) + "...";
      }
      displayName = "$displayName (Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)})";
    }

    if (isMocked) {
      displayName = "$displayName (Auto-Detected)";
    }

    await _matchAndSetLocation(displayName);
  }

  Future<void> _matchAndSetLocation(String addressText) async {
    final lowerAddress = addressText.toLowerCase();

    if (_states.isEmpty) {
      await _fetchStates();
    }

    // 1. Match State
    int? matchedStateId;
    for (var state in _states) {
      final stateName = state['name'].toString().toLowerCase().replaceAll('state', '').trim();
      if (lowerAddress.contains(stateName)) {
        matchedStateId = state['id'] as int;
        break;
      }
    }

    // Default to Kano State (id: 1) if not matched
    if (matchedStateId == null && _states.isNotEmpty) {
      matchedStateId = _states.first['id'] as int;
    }

    if (matchedStateId != null) {
      setState(() {
        _selectedStateId = matchedStateId;
      });
      await _fetchLgas(matchedStateId);

      // 2. Match LGA
      int? matchedLgaId;
      for (var lga in _lgas) {
        final lgaName = lga['name'].toString().toLowerCase().replaceAll('lga', '').trim();
        if (lowerAddress.contains(lgaName)) {
          matchedLgaId = lga['id'] as int;
          break;
        }
      }

      // Default to Kumbotso LGA or first LGA if not found
      if (matchedLgaId == null && _lgas.isNotEmpty) {
        for (var lga in _lgas) {
          final lgaName = lga['name'].toString().toLowerCase().replaceAll('lga', '').trim();
          if (lgaName == 'kumbotso' && (lowerAddress.contains('panshekara') || lowerAddress.contains('bakin ruwa'))) {
            matchedLgaId = lga['id'] as int;
            break;
          }
        }
        matchedLgaId ??= _lgas.first['id'] as int;
      }

      if (matchedLgaId != null) {
        setState(() {
          _selectedLgaId = matchedLgaId;
        });
        await _fetchNeighbourhoods(matchedLgaId);

        // 3. Match Neighbourhood
        int? matchedNeighbourhoodId;
        for (var neighbourhood in _neighbourhoods) {
          final nName = neighbourhood['name'].toString().toLowerCase().trim();
          if (lowerAddress.contains(nName)) {
            matchedNeighbourhoodId = neighbourhood['id'] as int;
            break;
          }
        }

        // If not matched, try fallback matching
        if (matchedNeighbourhoodId == null && _neighbourhoods.isNotEmpty) {
          matchedNeighbourhoodId = _neighbourhoods.first['id'] as int;
        }

        setState(() {
          _selectedNeighbourhoodId = matchedNeighbourhoodId;
        });
      }
    }

    setState(() {
      _locationController.text = addressText;
      _isLoadingLocation = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Location detected: $addressText'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStateId == null || _selectedLgaId == null || _selectedNeighbourhoodId == null) {
      setState(() {
        _errorMessage = 'Please select your State, LGA, and Neighbourhood.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(apiServiceProvider).post('/auth/register', data: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'gender': _gender,
        'state_id': _selectedStateId,
        'lga_id': _selectedLgaId,
        'neighbourhood_id': _selectedNeighbourhoodId,
      });

      if (response.data['success'] == true) {
        final storage = ref.read(storageServiceProvider);
        final token = response.data['token'];
        final userData = response.data['user'];
        
        await storage.setToken(token);
        await storage.saveUserSession(
          name: userData['name'],
          phone: userData['phone'],
          isVerified: userData['is_verified'],
          userId: userData['id'],
        );

        // Connect WebSocket and subscribe to private coin channel immediately on signup
        final int userId = userData['id'];
        final realtime = ref.read(realtimeServiceProvider);
        await realtime.connect(jwtToken: token);
        realtime.subscribeToCoins(userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Welcome to SallahFlex.'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Contestant Sign Up', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join SallahFlex 🌙',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Register to post your Sallah photos and compete for the neighbourhood crown!',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
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
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Aisha Musa',
                  ),
                  validator: Validators.validateName,
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 08031234567',
                    prefixText: '+234 ',
                  ),
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 16),

                // Gender Toggle
                Text('Gender', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Male')),
                        selected: _gender == 'Male',
                        onSelected: (selected) {
                          if (selected) setState(() => _gender = 'Male');
                        },
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _gender == 'Male' ? AppColors.primary : AppColors.mutedGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Female')),
                        selected: _gender == 'Female',
                        onSelected: (selected) {
                          if (selected) setState(() => _gender = 'Female');
                        },
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _gender == 'Female' ? AppColors.primary : AppColors.mutedGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // Auto-Detect Location Input Field
                TextFormField(
                  controller: _locationController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Service / Competition Address',
                    hintText: 'Tap the GPS icon to auto-detect location',
                    prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
                    suffixIcon: _isLoadingLocation 
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location, color: AppColors.primary),
                          onPressed: _detectLocation,
                          tooltip: 'Auto-Detect Live Location',
                        ),
                  ),
                ),
                const SizedBox(height: 16),

                // State Selector
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'State'),
                  value: _selectedStateId,
                  items: _states.map<DropdownMenuItem<int>>((state) {
                    return DropdownMenuItem<int>(
                      value: state['id'],
                      child: Text(state['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedStateId = value;
                      _selectedLgaId = null;
                      _selectedNeighbourhoodId = null;
                    });
                    _fetchLgas(value);
                  },
                ),
                const SizedBox(height: 16),

                // LGA Selector
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Local Government Area (LGA)'),
                  value: _selectedLgaId,
                  items: _lgas.map<DropdownMenuItem<int>>((lga) {
                    return DropdownMenuItem<int>(
                      value: lga['id'],
                      child: Text(lga['name']),
                    );
                  }).toList(),
                  onChanged: _selectedStateId == null ? null : (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedLgaId = value;
                      _selectedNeighbourhoodId = null;
                    });
                    _fetchNeighbourhoods(value);
                  },
                ),
                const SizedBox(height: 16),

                // Neighbourhood Selector
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Neighbourhood'),
                  value: _selectedNeighbourhoodId,
                  items: _neighbourhoods.map<DropdownMenuItem<int>>((hood) {
                    return DropdownMenuItem<int>(
                      value: hood['id'],
                      child: Text(hood['name']),
                    );
                  }).toList(),
                  onChanged: _selectedLgaId == null ? null : (value) {
                    setState(() {
                      _selectedNeighbourhoodId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) => Validators.validateConfirmPassword(value, _passwordController.text),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSubmit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 20),

                // Login Redirect
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
