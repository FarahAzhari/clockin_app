import 'dart:async';

import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:clockin_app/services/api_services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PersonReportScreen extends StatefulWidget {
  final ValueNotifier<bool> refreshNotifier;

  const PersonReportScreen({super.key, required this.refreshNotifier});

  @override
  State<PersonReportScreen> createState() => _PersonReportScreenState();
}

class _PersonReportScreenState extends State<PersonReportScreen> {
  final ApiService _apiService = ApiService();

  late Future<void>
  _reportDataFuture; // Changed to void as we update state directly
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  // Summary counts for the selected month
  int _presentCount = 0;
  int _absentCount = 0;
  int _totalEntriesCount = 0; // From total_absen in AbsenceStats
  String _totalWorkingHours = '0hr 0min';
  String _averageDailyWorkingHours = '0hr 0min'; // New: for average calculation

  // Data for Pie Chart
  List<PieChartSectionData> _pieChartSections = [];
  bool _showNoDataMessage = false; // New: To control showing "No Data" message

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _fetchAndCalculateMonthlyReports();

    widget.refreshNotifier.addListener(_handleRefreshSignal);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_handleRefreshSignal);
    super.dispose();
  }

  void _handleRefreshSignal() {
    if (widget.refreshNotifier.value) {
      print(
        'PersonReportScreen: Refresh signal received, refreshing reports...',
      );
      setState(() {
        _reportDataFuture = _fetchAndCalculateMonthlyReports();
      });
      widget.refreshNotifier.value = false;
    }
  }

  // Fetches attendance data and calculates monthly summaries
  Future<void> _fetchAndCalculateMonthlyReports() async {
    // Reset no data message at the start of fetching new data
    setState(() {
      _showNoDataMessage = false;
    });

    try {
      final String startDate = DateFormat('yyyy-MM-01').format(_selectedMonth);
      final String endDate = DateFormat('yyyy-MM-dd').format(
        DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          0,
        ), // Last day of the month
      );

      // Initialize local variables for calculation
      int localPresentCount = 0;
      int localAbsentCount = 0;
      int localTotalEntriesCount = 0;
      Duration localTotalWorkingDuration = Duration.zero;

      // --- 1. Fetch Absence Stats for summary counts ---
      final ApiResponse<AbsenceStats> statsResponse = await _apiService
          .getAbsenceStats(startDate: startDate, endDate: endDate);

      if (statsResponse.statusCode == 200 && statsResponse.data != null) {
        final AbsenceStats stats = statsResponse.data!;
        localPresentCount = stats.totalMasuk;
        localAbsentCount = stats.totalIzin;
        localTotalEntriesCount = stats.totalAbsen;
      } else {
        print(
          'Failed to get absence stats for reports: ${statsResponse.message}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load summary: ${statsResponse.message}'),
            ),
          );
        }
      }

      // --- 2. Fetch Absence History for total working hours ---
      final ApiResponse<List<Absence>> historyResponse = await _apiService
          .getAbsenceHistory(startDate: startDate, endDate: endDate);

      if (historyResponse.statusCode == 200 && historyResponse.data != null) {
        for (var absence in historyResponse.data!) {
          // Only calculate duration for 'masuk' entries that have both check-in and check-out times
          if (absence.status?.toLowerCase() == 'masuk' &&
              absence.checkIn != null &&
              absence.checkOut != null) {
            localTotalWorkingDuration += absence.checkOut!.difference(
              absence.checkIn!,
            );
          }
        }
      } else {
        print(
          'Failed to get absence history for working hours: ${historyResponse.message}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load working hours: ${historyResponse.message}',
              ),
            ),
          );
        }
      }

      // Calculate formatted total working hours
      final int totalHours = localTotalWorkingDuration.inHours;
      final int remainingMinutes = localTotalWorkingDuration.inMinutes
          .remainder(60);
      String formattedTotalWorkingHours = '${totalHours}j ${remainingMinutes}m';

      // Calculate Average Daily Working Hours
      String averageDailyWorkingHours = '0hr 0min';
      if (localPresentCount > 0) {
        final double averageMinutes =
            localTotalWorkingDuration.inMinutes / localPresentCount;
        final int avgHours = averageMinutes ~/ 60; // Integer division
        final int avgMinutes = (averageMinutes % 60)
            .round(); // Remainder minutes
        averageDailyWorkingHours = '${avgHours}j ${avgMinutes}m';
      }

      setState(() {
        _presentCount = localPresentCount;
        _absentCount = localAbsentCount;
        _totalEntriesCount = localTotalEntriesCount;
        _totalWorkingHours = formattedTotalWorkingHours;
        _averageDailyWorkingHours = averageDailyWorkingHours;
      });

      // Update Pie Chart Data after all counts are finalized
      _updatePieChartData(_presentCount, _absentCount);
    } catch (e) {
      print('Error fetching and calculating monthly reports: $e');
      // Reset all counts on error
      setState(() {
        _presentCount = 0;
        _absentCount = 0;
        _totalEntriesCount = 0;
        _totalWorkingHours = '0hr 0min';
        _averageDailyWorkingHours = '0hr 0min';
        _showNoDataMessage = true; // Show no data message on error
      });
      _updatePieChartData(0, 0); // Reset pie chart data on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred loading reports: $e')),
        );
      }
    }
  }

  // Method to update pie chart data
  void _updatePieChartData(int presentCount, int absentCount) {
    final total = presentCount + absentCount; // Only present and absent
    if (total == 0) {
      setState(() {
        _pieChartSections = [];
        _showNoDataMessage = true; // Show no data message
      });
      return;
    }

    const Color presentColor = Colors.green;
    const Color absentColor = Colors.red;

    setState(() {
      _pieChartSections = [
        if (presentCount > 0)
          PieChartSectionData(
            color: presentColor,
            value: presentCount.toDouble(),
            title: '${(presentCount / total * 100).toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _buildBadge('Hadir', presentColor),
            badgePositionPercentageOffset: .98,
          ),
        if (absentCount > 0)
          PieChartSectionData(
            color: absentColor,
            value: absentCount.toDouble(),
            title: '${(absentCount / total * 100).toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _buildBadge('Absen', absentColor),
            badgePositionPercentageOffset: .98,
          ),
      ];
      _showNoDataMessage = false; // Hide no data message if there's data
    });
  }

  // Helper for PieChart badges (labels)
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Method to show month picker (only month and year)
  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2101, 12, 31),
      initialDatePickerMode: DatePickerMode.year, // Start with year selection
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final DateTime newSelectedMonth = DateTime(picked.year, picked.month, 1);
      if (newSelectedMonth.year != _selectedMonth.year ||
          newSelectedMonth.month != _selectedMonth.month) {
        setState(() {
          _selectedMonth = newSelectedMonth;
          _reportDataFuture =
              _fetchAndCalculateMonthlyReports(); // Trigger re-fetch
        });
      }
    }
  }

  // Helper widget to build summary cards
  Widget _buildSummaryCard(String title, dynamic value, Color color) {
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
                      fontSize: 14,
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
                        value.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 28, // Original font size
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Absensi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: _reportDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Data is loaded, build the UI
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Laporan Bulanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _selectMonth(context),
                      child: Container(
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
                              DateFormat(
                                'MMM yyyy',
                                'id_ID', // Corrected format string
                              ).format(_selectedMonth).toUpperCase(),
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
                    ),
                  ],
                ),
              ),
              // Summary cards for the selected month in a 3x2 grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                  children: [
                    _buildSummaryCard(
                      'Total Hadir',
                      _presentCount.toString().padLeft(2, '0'),
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      'Total Absen',
                      _absentCount.toString().padLeft(2, '0'),
                      Colors.red,
                    ),
                    _buildSummaryCard(
                      'Total Hari', // Now distinct from Present/Absent
                      _totalEntriesCount.toString().padLeft(2, '0'),
                      Colors.blue,
                    ),
                    _buildSummaryCard(
                      'Total Waktu',
                      _totalWorkingHours,
                      AppColors.primary,
                    ),
                    _buildSummaryCard(
                      'Rata rata', // New card
                      _averageDailyWorkingHours,
                      Colors.deepOrange, // New color for this card
                    ),
                    _buildSummaryCard(
                      'Kehadiran %',
                      '${(_presentCount / (_totalEntriesCount == 0 ? 1 : _totalEntriesCount) * 100).toStringAsFixed(0)}%', // Updated calculation
                      Colors.teal,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
                child: Text(
                  'Rincian Status Kehadiran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        _showNoDataMessage // Conditional rendering
                        ? Center(
                            child: Text(
                              'Tidak Ada Data Pada Bulan Ini',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : PieChart(
                            PieChartData(
                              sections: _pieChartSections,
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event
                                                .isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection ==
                                                null) {
                                          return;
                                        }
                                      });
                                    },
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
