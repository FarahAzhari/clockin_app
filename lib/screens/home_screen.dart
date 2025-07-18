import 'dart:async';

import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:clockin_app/screens/attendance/request_screen.dart';
import 'package:clockin_app/screens/main_bottom_navigation_bar.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; // For reverse geocoding
import 'package:geolocator/geolocator.dart'; // For geolocation
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;
  const HomeScreen({super.key, required this.refreshNotifier});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  String _userName = 'User';
  String _location = 'Getting Location...';
  String _currentDate = '';
  String _currentTime = '';
  Timer? _timer;

  AbsenceToday? _todayAbsence; // Changed from AttendanceModel to AbsenceToday
  AbsenceStats? _absenceStats; // New state for attendance statistics

  Position? _currentPosition;
  bool _permissionGranted = false;
  bool _isCheckingInOrOut = false; // To prevent multiple taps during API calls

  // New: State for selected work mode (office or home)
  String _selectedMode = 'office'; // Default to office

  // New: Office location coordinates and radius for geofencing
  // IMPORTANT: Replace these with your actual office coordinates and desired radius (in meters)
  static const double _officeLatitude = -6.210881; // Example: Monas, Jakarta
  static const double _officeLongitude = 106.812942; // Example: Monas, Jakarta
  static const double _officeRadius = 100; // 100 meters radius

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _determinePosition(); // Start location fetching
    _loadUserData();
    _fetchAttendanceData(); // Fetch initial attendance data

    widget.refreshNotifier.addListener(_handleRefreshSignal);

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDateTime(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.refreshNotifier.removeListener(_handleRefreshSignal);
    super.dispose();
  }

  void _handleRefreshSignal() {
    if (widget.refreshNotifier.value) {
      print('HomeScreen: Refresh signal received, refreshing list...');
      _fetchAttendanceData(); // Re-fetch data for the home screen
      widget.refreshNotifier.value = false; // Reset the notifier after handling
    }
  }

  Future<void> _loadUserData() async {
    final ApiResponse<User> response = await _apiService.getProfile();
    if (response.statusCode == 200 && response.data != null) {
      setState(() {
        _userName = response.data!.name;
      });
    } else {
      print('Failed to load user profile: ${response.message}');
      setState(() {
        _userName = 'User'; // Default if profile fails
      });
    }
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateFormat('EEEE, dd MMMM yyyy').format(now);
      _currentTime = DateFormat('HH:mm:ss').format(now);
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      if (mounted) {
        _showErrorDialog('Location services are disabled. Please enable them.');
      }
      setState(() {
        _location = 'Location services disabled';
        _permissionGranted = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        if (mounted) {
          _showErrorDialog(
            'Location permissions are denied. Please grant them in settings.',
          );
        }
        setState(() {
          _location = 'Location permissions denied';
          _permissionGranted = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      if (mounted) {
        _showErrorDialog(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }
      setState(() {
        _location = 'Location permissions permanently denied';
        _permissionGranted = false;
      });
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
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
      print('Error getting current location: $e');
      if (mounted) {
        _showErrorDialog('Failed to get current location: $e');
      }
      setState(() {
        _location = 'Failed to get location';
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
        _location =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
      });
    } catch (e) {
      print('Error getting address from coordinates: $e');
      setState(() {
        _location = 'Address not found';
      });
    }
  }

  // Modified to use getAbsenceStats for monthly summary
  Future<void> _fetchAttendanceData() async {
    // Refresh location data as part of the overall refresh
    await _determinePosition();

    // Fetch today's absence record
    final ApiResponse<AbsenceToday> todayAbsenceResponse = await _apiService
        .getAbsenceToday();
    if (todayAbsenceResponse.statusCode == 200 &&
        todayAbsenceResponse.data != null) {
      final AbsenceToday fetchedTodayAbsence = todayAbsenceResponse.data!;
      final String currentFormattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());

      final String? fetchedAttendanceDate =
          fetchedTodayAbsence.attendanceDate != null
          ? DateFormat('yyyy-MM-dd').format(fetchedTodayAbsence.attendanceDate!)
          : null;
      if (fetchedAttendanceDate == currentFormattedDate) {
        setState(() {
          _todayAbsence = fetchedTodayAbsence;
        });
        print('UI State: _todayAbsence set to fetched data for current day.');
      } else {
        setState(() {
          _todayAbsence = null;
        });
        print(
          'UI State: _todayAbsence set to null (data for different day or null date).',
        );
      }
      print('--- End Debugging ---');
    } else {
      print('Failed to get today\'s absence: ${todayAbsenceResponse.message}');
      setState(() {
        _todayAbsence = null; // Reset if no record or error
      });
    }

    // --- NEW: Fetch attendance stats for the current month using getAbsenceStats ---
    final DateTime now = DateTime.now();
    final DateTime startOfMonth = DateTime(now.year, now.month, 1);
    final DateTime endOfMonth = DateTime(
      now.year,
      now.month + 1,
      0,
    ); // Last day of current month

    final String formattedStartDate = DateFormat(
      'yyyy-MM-dd',
    ).format(startOfMonth);
    final String formattedEndDate = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final ApiResponse<AbsenceStats> statsResponse = await _apiService
        .getAbsenceStats(
          startDate: formattedStartDate,
          endDate: formattedEndDate,
        );

    if (statsResponse.statusCode == 200 && statsResponse.data != null) {
      setState(() {
        _absenceStats = statsResponse.data;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load monthly summary: ${statsResponse.message}',
            ),
          ),
        );
      }
      setState(() {
        _absenceStats = null; // Reset if no stats or error
      });
    }
  }

  // New: Helper to check if current location is within office radius
  bool _isWithinOfficeLocation() {
    if (_currentPosition == null) {
      return false;
    }
    final double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _officeLatitude,
      _officeLongitude,
    );
    return distance <= _officeRadius;
  }

  Future<void> _handleCheckIn() async {
    if (!_permissionGranted || _currentPosition == null) {
      _showErrorDialog(
        'Location not available. Please ensure location services are enabled and permissions are granted.',
      );
      await _determinePosition(); // Try to get location again
      return;
    }
    if (_isCheckingInOrOut) return; // Prevent double tap

    // New: Location check based on selected mode
    if (_selectedMode == 'office' && !_isWithinOfficeLocation()) {
      _showErrorDialog(
        'You are not within the office location. Check-in is only allowed within the office for "Office" mode.',
      );
      return;
    }

    setState(() {
      _isCheckingInOrOut = true;
    });

    try {
      final String formattedAttendanceDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      final String formattedCheckInTime = DateFormat(
        'HH:mm',
      ).format(DateTime.now());

      // Determine status based on selected mode: always 'masuk' for work-related check-ins
      final String statusToSend =
          'masuk'; // Changed from _selectedMode == 'office' ? 'masuk' : 'wfh';

      final ApiResponse<Absence> response = await _apiService.checkIn(
        checkInLat: _currentPosition!.latitude,
        checkInLng: _currentPosition!.longitude,
        checkInAddress: _location,
        status: statusToSend, // Use 'masuk' for both office and home check-ins
        attendanceDate: formattedAttendanceDate,
        checkInTime: formattedCheckInTime,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
        _fetchAttendanceData(); // Refresh home after check-in
        MainBottomNavigationBar.refreshAttendanceNotifier.value =
            true; // Signal AttendanceListScreen
      } else {
        String errorMessage = response.message;
        if (response.errors != null) {
          response.errors!.forEach((key, value) {
            errorMessage += '\n$key: ${(value as List).join(', ')}';
          });
        }
        if (mounted) {
          _showErrorDialog('Check In Failed: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred during check-in: $e');
      }
    } finally {
      setState(() {
        _isCheckingInOrOut = false;
      });
    }
  }

  Future<void> _handleCheckOut() async {
    if (!_permissionGranted || _currentPosition == null) {
      _showErrorDialog(
        'Location not available. Please ensure location services are enabled and permissions are granted.',
      );
      await _determinePosition(); // Try to get location again
      return;
    }
    if (_isCheckingInOrOut) return; // Prevent double tap

    // New: Location check based on selected mode
    if (_selectedMode == 'office' && !_isWithinOfficeLocation()) {
      _showErrorDialog(
        'You are not within the office location. Check-out is only allowed within the office for "Office" mode.',
      );
      return;
    }

    setState(() {
      _isCheckingInOrOut = true;
    });

    try {
      final String formattedAttendanceDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      final String formattedCheckOutTime = DateFormat(
        'HH:mm',
      ).format(DateTime.now());

      // Determine status based on selected mode: always 'masuk' for work-related check-outs
      // final String statusToSend = 'masuk'; // Changed from _selectedMode == 'office' ? 'masuk' : 'wfh';

      final ApiResponse<Absence> response = await _apiService.checkOut(
        checkOutLat: _currentPosition!.latitude,
        checkOutLng: _currentPosition!.longitude,
        checkOutAddress: _location,
        attendanceDate: formattedAttendanceDate,
        checkOutTime: formattedCheckOutTime,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
        _fetchAttendanceData(); // Refresh home after check-out
        MainBottomNavigationBar.refreshAttendanceNotifier.value =
            true; // Signal AttendanceListScreen
      } else {
        String errorMessage = response.message;
        if (response.errors != null) {
          response.errors!.forEach((key, value) {
            errorMessage += '\n$key: ${(value as List).join(', ')}';
          });
        }
        if (mounted) {
          _showErrorDialog('Check Out Failed: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred during check-out: $e');
      }
    } finally {
      setState(() {
        _isCheckingInOrOut = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  String _calculateWorkingHours() {
    if (_todayAbsence == null || _todayAbsence!.jamMasuk == null) {
      return '00:00:00'; // No check-in yet or jamMasuk is null
    }

    final DateTime checkInDateTime =
        _todayAbsence!.jamMasuk!; // Null-check added
    DateTime endDateTime;

    if (_todayAbsence!.jamKeluar != null) {
      endDateTime = _todayAbsence!.jamKeluar!; // Null-check added
    } else {
      endDateTime = DateTime.now(); // Use current time for live calculation
    }

    final Duration duration = endDateTime.difference(checkInDateTime);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCheckedIn = _todayAbsence?.jamMasuk != null;
    final bool hasCheckedOut = _todayAbsence?.jamKeluar != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    // Handle notification button press
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh:
                _fetchAttendanceData, // This method will be called on pull-to-refresh
            child: ListView(
              padding: const EdgeInsets.only(top: 5),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Welcome, $_userName',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMainActionCard(hasCheckedIn, hasCheckedOut),
                const SizedBox(height: 20),
                _buildAttendanceSummary(),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RequestScreen()),
                  );
                  if (result == true) {
                    _fetchAttendanceData(); // Refresh home after request
                    MainBottomNavigationBar.refreshAttendanceNotifier.value =
                        true; // Signal AttendanceListScreen
                  }
                },
                icon: const Icon(Icons.add_task, color: AppColors.primary),
                label: const Text(
                  'Permission Request',
                  style: TextStyle(color: AppColors.primary, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionCard(bool hasCheckedIn, bool hasCheckedOut) {
    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedMode = 'home';
                      });
                    },
                    icon: Icon(
                      Icons.home,
                      color: _selectedMode == 'home'
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    label: Text(
                      'Home',
                      style: TextStyle(
                        color: _selectedMode == 'home'
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _selectedMode == 'home'
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: _selectedMode == 'home'
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedMode = 'office';
                      });
                    },
                    icon: Icon(
                      Icons.business,
                      color: _selectedMode == 'office'
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    label: Text(
                      'Office',
                      style: TextStyle(
                        color: _selectedMode == 'office'
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _selectedMode == 'office'
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: _selectedMode == 'office'
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'GENERAL SHIFT', // This seems static, keep as is
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      _currentDate,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isCheckingInOrOut
                      ? null // Disable button if an operation is in progress
                      : (hasCheckedIn
                            ? (hasCheckedOut ? null : _handleCheckOut)
                            : _handleCheckIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasCheckedIn
                        ? (hasCheckedOut ? Colors.grey : Colors.redAccent)
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                  child: _isCheckingInOrOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          hasCheckedIn
                              ? (hasCheckedOut ? 'Checked Out' : 'Check Out')
                              : 'Check In',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeDetail(
                  Icons.watch_later_outlined,
                  // Safely access jamMasuk and format it, provide 'N/A' if null
                  _todayAbsence?.jamMasuk?.toLocal().toString().substring(
                        11,
                        19,
                      ) ??
                      'N/A',
                  'Check In',
                  AppColors.primary,
                ),
                _buildTimeDetail(
                  Icons.watch_later_outlined,
                  // Safely access jamKeluar and format it, provide 'N/A' if null
                  _todayAbsence?.jamKeluar?.toLocal().toString().substring(
                        11,
                        19,
                      ) ??
                      'N/A',
                  'Check Out',
                  Colors.redAccent,
                ),
                _buildTimeDetail(
                  Icons.watch_later_outlined,
                  _calculateWorkingHours(),
                  'Working HR\'s',
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDetail(
    IconData icon,
    String time,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildAttendanceSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance for this Month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('MMM yyyy')
                          .format(DateTime.now())
                          .toUpperCase(), // Display current month and year
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              _buildSummaryCard(
                'Present',
                _absenceStats?.totalMasuk ?? 0,
                Colors.green,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Absents',
                _absenceStats?.totalIzin ?? 0,
                Colors.red,
              ), // Assuming 'total_izin' maps to absents/leaves
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Total',
                _absenceStats?.totalAbsen ?? 0,
                Colors.blue,
              ), // Assuming 'total_absen' means total entries for the month
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        child: Column(
          children: [
            Container(
              height: 5.0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1, // Ensure title stays on one line
                    overflow:
                        TextOverflow.ellipsis, // Add ellipsis if it overflows
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FittedBox(
                      // Use FittedBox to prevent overflow for value
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Text(
                        count.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 32, // Original font size
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
