// lib/screens/profile/edit_profile_screen.dart
import 'dart:convert'; // For base64 encoding
import 'dart:io'; // For File operations

import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import for image picking

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
  String? _selectedJenisKelamin; // New state for Jenis Kelamin
  File? _pickedImage; // New state for picked profile photo file
  String? _profilePhotoBase64; // New state for base64 encoded photo

  bool _isLoading = false; // Add loading state

  @override
  void initState() {
    super.initState();
    // Initialize controller with current user's name
    _usernameController = TextEditingController(
      text: widget.currentUser.name, // Use .name property
    );

    // Initialize selected gender
    _selectedJenisKelamin = widget.currentUser.jenis_kelamin;

    // Initialize profile photo if available
    if (widget.currentUser.profile_photo != null &&
        widget.currentUser.profile_photo!.isNotEmpty) {
      _profilePhotoBase64 = widget.currentUser.profile_photo;
      // Note: We don't re-create a File object from base64 here
      // as it's not directly used for display in the CircleAvatar
      // and would require saving to a temp file, which is unnecessary
      // unless you need to re-upload the *same* image file.
      // We will use MemoryImage for display.
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
      // Convert image to base64
      List<int> imageBytes = await _pickedImage!.readAsBytes();
      _profilePhotoBase64 = base64Encode(imageBytes);
    }
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
          jenisKelamin: _selectedJenisKelamin, // Pass selected gender
          profilePhoto: _profilePhotoBase64, // Pass base64 photo
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
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (_profilePhotoBase64 != null &&
                                          _profilePhotoBase64!.isNotEmpty
                                      ? MemoryImage(
                                          base64Decode(_profilePhotoBase64!),
                                        )
                                      : null)
                                  as ImageProvider<Object>?,
                        child:
                            _pickedImage == null &&
                                (_profilePhotoBase64 == null ||
                                    _profilePhotoBase64!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.textLight,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _pickImage,
                      child: Text(
                        _pickedImage != null || _profilePhotoBase64 != null
                            ? 'Change Photo'
                            : 'Upload Photo',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
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
              const SizedBox(height: 16),

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
