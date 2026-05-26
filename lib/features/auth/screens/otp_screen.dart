import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String type; // 'register' or 'reset'

  const OtpScreen({
    super.key,
    required this.phone,
    required this.type,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final endpoint = widget.type == 'register' ? '/auth/register' : '/auth/forgot-password';
      final response = await ref.read(apiServiceProvider).post(endpoint, data: {
        'phone': widget.phone,
      });

      if (response.data['success'] == true) {
        final debugOtp = response.data['debug_otp'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP Resent! Debug OTP: $debugOtp'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
        _startTimer();
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

  Future<void> _verifyOtp() async {
    final otpCode = _controllers.map((c) => c.text).join();
    if (otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(apiServiceProvider).post('/auth/verify-otp', data: {
        'phone': widget.phone,
        'otp_code': otpCode,
        'type': widget.type,
      });

      if (response.data['success'] == true) {
        final storage = ref.read(storageServiceProvider);
        
        if (widget.type == 'register') {
          // Save session tokens E2E
          final token = response.data['token'];
          final userData = response.data['user'];
          
          await storage.setToken(token);
          await storage.saveUserSession(
            name: userData['name'],
            phone: userData['phone'],
            isVerified: userData['is_verified'],
          );

          if (mounted) {
            context.go('/home');
          }
        } else {
          // Password reset verified, redirect to change password
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP verified successfully! Log in with your new password.'),
                backgroundColor: AppColors.successGreen,
              ),
            );
            context.go('/login');
          }
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
        title: Text('OTP Verification', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify Your Number 🔐',
                style: AppTextStyles.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to +234 ${widget.phone}. Enter it below to activate your account.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedGray),
              ),
              const SizedBox(height: 30),
              
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

              // 6 Digits Inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 48,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          // Advance to next box
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                            _verifyOtp(); // Auto-verify on last digit
                          }
                        } else {
                          // Go backward on backspace
                          if (index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Account'),
                ),
              ),
              const SizedBox(height: 24),

              // Resend Code Countdown
              Center(
                child: TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _resendCode,
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Resend Code in ${_secondsRemaining}s'
                        : 'Resend OTP Code',
                    style: TextStyle(
                      color: _secondsRemaining > 0 ? AppColors.mutedGray : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
