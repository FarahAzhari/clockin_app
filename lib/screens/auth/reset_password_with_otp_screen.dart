import 'dart:async'; // Import for Timer

import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/constants/app_text_styles.dart';
import 'package:clockin_app/routes/app_routes.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:clockin_app/widgets/custom_input_field.dart';
import 'package:clockin_app/widgets/primary_button.dart';
import 'package:flutter/material.dart';

class ResetPasswordWithOtpScreen extends StatefulWidget {
  final String email; // Email passed from ForgotPasswordScreen

  const ResetPasswordWithOtpScreen({super.key, required this.email});

  @override
  State<ResetPasswordWithOtpScreen> createState() =>
      _ResetPasswordWithOtpScreenState();
}

class _ResetPasswordWithOtpScreenState
    extends State<ResetPasswordWithOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Timer related variables
  Timer? _otpTimer;
  int _remainingSeconds = 600; // 10 minutes in seconds

  @override
  void initState() {
    super.initState();
    _startOtpTimer();
  }

  @override
  void dispose() {
    _otpTimer?.cancel(); // Cancel the timer when the widget is disposed
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpTimer?.cancel(); // Cancel any existing timer
    _remainingSeconds = 600; // Reset to 10 minutes
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _otpTimer?.cancel(); // Stop the timer when it reaches 0
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Future<void> _requestNewOtp() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _apiService.forgotPassword(email: widget.email);

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      _showSnackBar(response.message);
      _startOtpTimer(); // Restart the timer
    } else {
      String errorMessage = response.message;
      if (response.errors != null) {
        response.errors!.forEach((key, value) {
          errorMessage += '\n$key: ${(value as List).join(', ')}';
        });
      }
      _showSnackBar(errorMessage);
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      if (_remainingSeconds == 0) {
        _showSnackBar('OTP kadaluarsa. Mohon ajukan yang baru.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final String otp = _otpController.text.trim();
      final String newPassword = _newPasswordController.text.trim();
      final String confirmPassword = _confirmPasswordController.text.trim();

      final response = await _apiService.resetPassword(
        email: widget.email,
        otp: otp,
        newPassword: newPassword,
        newPasswordConfirmation: confirmPassword,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        _showSnackBar(response.message);
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } else {
        String errorMessage = response.message;
        if (response.errors != null) {
          response.errors!.forEach((key, value) {
            errorMessage += '\n$key: ${(value as List).join(', ')}';
          });
        }
        _showSnackBar(errorMessage);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool otpExpired = _remainingSeconds == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                "Masukkan OTP dan Password yang baru",
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 10),
              Text(
                "OTP sudah terkirim ke ${widget.email}. Mohon masukkan OTP di bawah ini dengan password baru.",
                style: AppTextStyles.normal,
              ),
              const SizedBox(height: 30),
              CustomInputField(
                controller: TextEditingController(
                  text: widget.email,
                ), // Display email, not editable
                hintText: 'Email',
                labelText: 'Alamat Email',
                icon: Icons.email_outlined,
                readOnly: true,
              ),
              const SizedBox(height: 20),
              CustomInputField(
                controller: _otpController,
                hintText: 'OTP',
                labelText: 'One-Time Password (OTP)',
                icon: Icons.vpn_key_outlined,
                keyboardType: TextInputType.number,
                customValidator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'OTP tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // OTP Timer display
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  otpExpired
                      ? 'OTP Kadaluarsa'
                      : 'OTP kadaluarsa dalam ${_formatTime(_remainingSeconds)}',
                  style: TextStyle(
                    color: otpExpired ? AppColors.error : AppColors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CustomInputField(
                controller: _newPasswordController,
                hintText: 'Password Baru',
                labelText: 'Password Baru',
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: !_isNewPasswordVisible,
                toggleVisibility: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
                customValidator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru tidak boleh kosong';
                  }
                  if (value.length < 8) {
                    return 'Kata sandi harus terdiri dari setidaknya 6 karakter.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomInputField(
                controller: _confirmPasswordController,
                hintText: 'Konfirmasi Password Baru',
                labelText: 'Konfirmasi Password Baru',
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: !_isConfirmPasswordVisible,
                toggleVisibility: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
                customValidator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru tidak boleh kosong';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Password tidak sama';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : PrimaryButton(
                      label: 'Reset Password',
                      onPressed: otpExpired
                          ? () {}
                          : () => _resetPassword(), // Changed null to () {}
                    ),
              if (otpExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? () {}
                          : () => _requestNewOtp(), // Changed null to () {}
                      child: const Text(
                        'Kirim Ulang OTP',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
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
