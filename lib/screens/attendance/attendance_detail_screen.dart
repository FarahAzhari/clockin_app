import 'package:clockin_app/constants/app_colors.dart';
import 'package:clockin_app/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceDetailScreen extends StatelessWidget {
  final Absence attendance;

  const AttendanceDetailScreen({super.key, required this.attendance});

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'N/A';
    }
    return DateFormat('HH:mm:ss').format(dateTime.toLocal());
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'N/A';
    }
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dateTime.toLocal());
  }

  String _calculateWorkingHours(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null) {
      return '00:00:00';
    }

    DateTime endDateTime = checkOut ?? DateTime.now();
    final Duration duration = endDateTime.difference(checkIn);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    bool isRequestType = attendance.status?.toLowerCase() == 'izin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Detail'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: AppColors.background,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Tanggal',
                  _formatDate(attendance.attendanceDate),
                  Icons.calendar_today,
                ),
                const Divider(),
                _buildDetailRow(
                  'Status',
                  attendance.status?.toUpperCase() ?? 'N/A',
                  Icons.info_outline,
                  valueColor: isRequestType
                      ? AppColors.accentOrange
                      : (attendance.status?.toLowerCase() == 'late'
                            ? AppColors.accentRed
                            : AppColors.accentGreen),
                ),
                const Divider(),
                if (!isRequestType) ...[
                  _buildDetailRow(
                    'Jam Masuk',
                    _formatDateTime(attendance.checkIn),
                    Icons.login,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Check In Lokasi (Alamat)',
                    attendance.checkInAddress ?? 'N/A',
                    Icons.location_on,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Check In Lokasi (Kordinat)',
                    attendance.checkInLocation ?? 'N/A',
                    Icons.gps_fixed,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Jam Keluar',
                    _formatDateTime(attendance.checkIn),
                    Icons.logout,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Check Out Lokasi (Alamat)',
                    attendance.checkOutAddress ?? 'N/A',
                    Icons.location_on,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Check Out Lokasi (Kordinat)',
                    attendance.checkOutLocation ?? 'N/A',
                    Icons.gps_fixed,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Total Waktu',
                    _calculateWorkingHours(
                      attendance.checkIn,
                      attendance.checkOut,
                    ),
                    Icons.access_time,
                  ),
                ] else ...[
                  _buildDetailRow(
                    'Reason for Request',
                    attendance.alasanIzin?.isNotEmpty == true
                        ? attendance.alasanIzin!
                        : 'No reason provided',
                    Icons.notes,
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
