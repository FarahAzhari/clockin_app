import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:flutter/material.dart';

import '../../widgets/custom_input_field.dart'; // Your CustomInputField
import '../../widgets/primary_button.dart'; // Your PrimaryButton

class EditProfileScreen extends StatefulWidget {
  final User currentUser; // Changed type to User

  const EditProfileScreen({super.key, required this.currentUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService(); // Use ApiService
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  bool _isLoading = false; // Add loading state

  @override
  void initState() {
    super.initState();
    // Initialize controller with current user's name
    _usernameController = TextEditingController(
      text: widget.currentUser.name, // Use .name property
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true; // Set loading to true
      });

      final String newUsername = _usernameController.text.trim();

      try {
        // Call the editProfile method in ApiService
        final ApiResponse<User> response = await _apiService.editProfile(
          name: newUsername,
        );

        if (!mounted) return; // Check if the widget is still in the tree

        if (response.statusCode == 200 && response.data != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(response.message)));
          Navigator.pop(context, true); // Pop with true to signal refresh
        } else {
          String errorMessage = response.message;
          if (response.errors != null) {
            response.errors!.forEach((key, value) {
              errorMessage += '\n$key: ${(value as List).join(', ')}';
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $errorMessage')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      } finally {
        setState(() {
          _isLoading = false; // Set loading to false
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(
                        0.2,
                      ), // Light background for avatar
                      // No image provider from API, so always show default icon
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Removed "Change Photo" button as API doesn't support image upload
                  ],
                ),
              ),
              const SizedBox(
                height: 24,
              ), // Space between image section and first input
              // Username (editable) using CustomInputField
              CustomInputField(
                controller: _usernameController,
                hintText: 'Username',
                labelText: 'Username',
                icon: Icons.person,
                customValidator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (display only - not editable via editProfile API)
              CustomInputField(
                controller: TextEditingController(
                  text: widget.currentUser.email,
                ),
                hintText: 'Email',
                labelText: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                readOnly:
                    true, // Make email read-only as it's not editable via this API
                customValidator: (value) {
                  // No validation needed for read-only field, but keeping for CustomInputField signature
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button using PrimaryButton
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : PrimaryButton(
                      label: 'Save Profile',
                      onPressed: _saveProfile,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
