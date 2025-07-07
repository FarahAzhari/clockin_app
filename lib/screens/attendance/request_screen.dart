import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; // For reverse geocoding
import 'package:geolocator/geolocator.dart'; // For geolocation

import '../../widgets/custom_date_input_field.dart'; // Your CustomDateInputField
import '../../widgets/custom_dropdown_input_field.dart'; // Your CustomDropdownInputField
import '../../widgets/custom_input_field.dart'; // Your CustomInputField
import '../../widgets/primary_button.dart'; // Your PrimaryButton

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final ApiService _apiService = ApiService(); // Use ApiService
  DateTime? _selectedDate;
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedRequestType; // To store the selected request type

  Position? _currentPosition;
  String _locationAddress = 'Getting Location...';
  bool _permissionGranted = false;
  bool _isLoading = false; // Add loading state

  final List<String> _requestTypes = [
    'Absent',
    'Leave',
    'Sick',
    'Permission',
    'Business Trip',
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Start location fetching
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showSnackBar('Location services are disabled. Please enable them.');
      }
      setState(() {
        _locationAddress = 'Location services disabled';
        _permissionGranted = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showSnackBar(
            'Location permissions are denied. Please grant them in settings.',
          );
        }
        setState(() {
          _locationAddress = 'Location permissions denied';
          _permissionGranted = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showSnackBar(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }
      setState(() {
        _locationAddress = 'Location permissions permanently denied';
        _permissionGranted = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _permissionGranted = true;
      });
      await _getAddressFromLatLng(position);
    } catch (e) {
      print('Error getting current location for request: $e');
      if (mounted) {
        _showSnackBar('Failed to get current location: $e');
      }
      setState(() {
        _locationAddress = 'Failed to get location';
        _permissionGranted = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];
      setState(() {
        _locationAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
      });
    } catch (e) {
      print('Error getting address from coordinates for request: $e');
      setState(() {
        _locationAddress = 'Address not found';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: AppColors.textDark, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_permissionGranted || _currentPosition == null) {
      _showSnackBar(
        'Location not available. Please ensure location services are enabled and permissions are granted.',
      );
      await _determinePosition(); // Try to get location again
      return;
    }

    // Basic validation
    if (_selectedDate == null) {
      _showSnackBar('Please select a date.');
      return;
    }
    if (_reasonController.text.isEmpty) {
      _showSnackBar('Please enter a reason for the request.');
      return;
    }
    if (_selectedRequestType == null) {
      _showSnackBar('Please select a request type.');
      return;
    }

    setState(() {
      _isLoading = true; // Set loading to true
    });

    try {
      // For requests (izin, leave, sick, etc.), we use the checkIn endpoint
      // with status 'izin' and the selected type/reason in 'alasan_izin'.
      final ApiResponse<Absence> response = await _apiService.checkIn(
        checkInLat: _currentPosition!.latitude,
        checkInLng: _currentPosition!.longitude,
        checkInAddress: _locationAddress,
        status: 'izin', // All requests are 'izin' status
        alasanIzin:
            '${_selectedRequestType!}: ${_reasonController.text.trim()}',
      );

      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          _showSnackBar('Request submitted successfully!');
          Navigator.pop(context, true); // Pop with true to indicate success
        }
      } else {
        String errorMessage = response.message;
        if (response.errors != null) {
          response.errors!.forEach((key, value) {
            errorMessage += '\n$key: ${(value as List).join(', ')}';
          });
        }
        if (mounted) {
          _showSnackBar('Failed to submit request: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred: $e');
      }
    } finally {
      setState(() {
        _isLoading = false; // Set loading to false
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Request'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display current location
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
            // Date Picker using CustomDateInputField
            CustomDateInputField(
              labelText: 'Select Date',
              icon: Icons.calendar_today,
              selectedDate: _selectedDate,
              onTap: () => _selectDate(context),
              hintText: 'No date chosen', // Optional hint text
            ),
            const SizedBox(height: 20),

            // Request Type Dropdown using CustomDropdownInputField
            CustomDropdownInputField<String>(
              labelText: 'Request Type',
              icon: Icons.category,
              value: _selectedRequestType,
              hintText: 'Select request type',
              items: _requestTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedRequestType = newValue;
                });
              },
            ),
            const SizedBox(height: 20),

            // Reason Text Field using CustomInputField
            CustomInputField(
              controller: _reasonController,
              labelText:
                  'Reason for Request', // This becomes the floating label
              hintText:
                  'e.g., Annual leave, sick leave, personal matters', // This remains the hint text inside the field
              icon: Icons.edit_note,
              maxLines: 3, // Allow multiline input
              keyboardType:
                  TextInputType.multiline, // Set keyboard to multiline
              fillColor: AppColors.inputFill, // Match previous fillColor
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ), // Adjusted vertical padding
              customValidator: (value) {
                // Use customValidator for specific validation
                if (value == null || value.trim().isEmpty) {
                  return 'Reason cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            // Submit Button using PrimaryButton
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : PrimaryButton(
                    label: 'Submit Request',
                    onPressed: _submitRequest,
                  ),
          ],
        ),
      ),
    );
  }
}
