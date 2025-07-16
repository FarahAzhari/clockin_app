import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/constants/app_text_styles.dart';
import 'package:clockin_app/routes/app_routes.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:clockin_app/widgets/custom_input_field.dart';
import 'package:clockin_app/widgets/primary_button.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _requestOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showSnackBar('Mohon masukkan alamat email yang valid');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String email = _emailController.text.trim();
    final response = await _apiService.forgotPassword(email: email);

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      _showSnackBar(response.message);
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.resetPasswordWithOtp,
          arguments: email, // Pass the email to the next screen
        );
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lupa Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text("Reset Password", style: AppTextStyles.heading),
            const SizedBox(height: 10),
            const Text(
              "Masukkan alamat email untuk menerima one-time password (OTP).",
              style: AppTextStyles.normal,
            ),
            const SizedBox(height: 30),
            CustomInputField(
              controller: _emailController,
              hintText: 'Email',
              labelText: 'Alamat Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              customValidator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                if (!value.contains('@')) {
                  return 'Mohon masukkan email yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : PrimaryButton(label: 'Request OTP', onPressed: _requestOtp),
          ],
        ),
      ),
    );
  }
}
