import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_location.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/demo_badge.dart';

/// Module Screen: Emergency SOS & Response Trigger matching 13_SOS_confirmation.png & 14_SOS_details_to_share.png.
class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _holdController;
  bool _isHolding = false;
  bool _isSosTriggered = false;
  UserLocation get _location => UserProfileService.currentLocation;
  UserProfile get _profile => UserProfileService.currentProfile;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isSosTriggered = true;
            _isHolding = false;
          });
          HapticFeedback.heavyImpact();
        }
      });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_isSosTriggered) return;
    setState(() => _isHolding = true);
    _holdController.forward();
    HapticFeedback.mediumImpact();
  }

  void _onHoldEnd() {
    if (_isSosTriggered) return;
    setState(() => _isHolding = false);
    _holdController.reverse();
  }

  void _resetSos() {
    setState(() {
      _isSosTriggered = false;
      _isHolding = false;
    });
    _holdController.reset();
  }

  String _generateSosPacket() {
    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final fixType = _location.isMock ? 'DEMO LOCATION (Live location unavailable)' : 'LIVE GPS FIX';
    final coordLabel = _location.isMock ? 'Demo Coordinates' : 'GPS Coordinates';
    final accuracyStr = _location.accuracyMeters != null
        ? '\nAccuracy: ±${_location.accuracyMeters!.toStringAsFixed(1)}m (GPS Telemetry)'
        : '';

    final headcountStr = _profile.isHeadcountConfigured
        ? 'Headcount: ${_profile.totalPeople} people (${_profile.adults ?? 0} adults, ${_profile.children ?? 0} children, ${_profile.seniors ?? 0} seniors)\n'
          'Pets / Animals: ${_profile.pets ?? 0}\n'
          'Mobility Assistance: ${_profile.needsMobilityAssistance ? "Required (Wheelchair)" : "Standard"}\n'
        : 'Headcount: Not provided (Profile unconfigured)\n';

    return 'EMERGENCY SOS - SURAKSHAPATH\n'
        'Location Fix: $fixType\n'
        '$coordLabel: ${_location.formattedCoordinates}$accuracyStr\n'
        'Corridor: ${_location.locationName}, ${_location.subArea}\n'
        'Timestamp: $timeStr\n'
        '$headcountStr'
        'Status: Emergency Assistance Protocol Prepared (Manual Dispatch Required)\n'
        'Note: Preparedness Drill Mode • Direct Helpline Dispatch (112 / 108)\n'
        'Region: Coastal Andhra Pradesh Emergency Grid';
  }

  void _copyDetailsToClipboard() {
    final text = _generateSosPacket();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency packet copied to clipboard.'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Future<void> _callEmergencyNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to launch phone dialer for $number on this device.'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dialer launch error: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  Future<void> _sendLocationSms() async {
    final body = _generateSosPacket();
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': body},
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _copyDetailsToClipboard();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS app not available. Emergency packet copied to clipboard.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
    } catch (_) {
      _copyDetailsToClipboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open SMS. Emergency packet copied to clipboard.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A), // Deep Navy / Dark Surface
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            titleSpacing: 0,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.emergencySosTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: Center(child: DemoBadge(label: 'DRILL MODE', dark: true)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // 1. Instructions Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.critical, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isSosTriggered
                              ? AppStrings.sosActivated
                              : 'Press and hold the button for 3 seconds to activate emergency protocol and prepare location broadcast.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 2. 3-Second Circular Hold Button
                GestureDetector(
                  onTapDown: (_) => _onHoldStart(),
                  onTapUp: (_) => _onHoldEnd(),
                  onTapCancel: () => _onHoldEnd(),
                  child: AnimatedBuilder(
                    animation: _holdController,
                    builder: (context, _) {
                      final progress = _holdController.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer progress ring
                          SizedBox(
                            width: 190,
                            height: 190,
                            child: CircularProgressIndicator(
                              value: _isSosTriggered ? 1.0 : progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isSosTriggered ? AppColors.emerald : AppColors.critical,
                              ),
                            ),
                          ),
                          // Inner circle
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSosTriggered
                                  ? AppColors.emerald
                                  : (_isHolding ? AppColors.critical : const Color(0xFF1E293B)),
                              border: Border.all(
                                color: _isSosTriggered ? AppColors.emerald : AppColors.critical,
                                width: 3.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isSosTriggered ? AppColors.emerald : AppColors.critical)
                                      .withValues(alpha: _isHolding ? 0.6 : 0.25),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FlaticonView(
                                  assetPath: AppIcons.sos,
                                  size: 48,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isSosTriggered
                                      ? 'ACTIVE'
                                      : (_isHolding ? 'HOLDING...' : 'HOLD 3s'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  _isSosTriggered
                      ? AppStrings.sosActivated
                      : (_isHolding ? AppStrings.releaseToCancel : AppStrings.holdFor3Seconds),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isSosTriggered ? AppColors.emerald : const Color(0xFF94A3B8),
                  ),
                ),

                if (_isSosTriggered) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _resetSos,
                    child: const Text('Reset SOS Signal', style: TextStyle(color: Colors.white70)),
                  ),
                ],
                const SizedBox(height: 28),

                // 3. Quick Emergency Call Buttons
                _buildActionCallButton(
                  title: AppStrings.call112,
                  subtitle: 'Police • Fire • National Emergency (Direct Dial)',
                  icon: Icons.phone_in_talk,
                  color: AppColors.critical,
                  onTap: () => _callEmergencyNumber('112'),
                ),
                const SizedBox(height: 12),
                _buildActionCallButton(
                  title: AppStrings.call108,
                  subtitle: 'State Ambulance & Immediate Medical Relief (Direct Dial)',
                  icon: Icons.medical_services_rounded,
                  color: AppColors.high,
                  onTap: () => _callEmergencyNumber('108'),
                ),
                const SizedBox(height: 24),

                // 4. Emergency Details Package Card (14_SOS_details_to_share.png)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Emergency Broadcast Packet',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          DemoBadge(label: 'READY', dark: true),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFF334155)),
                      _buildDetailRow(
                        'Location Fix',
                        _location.isMock ? 'Live location unavailable' : 'Live GPS Fix',
                      ),
                      _buildDetailRow(
                        _location.isMock ? 'Demo Location' : 'GPS Coordinates',
                        _location.accuracyMeters != null
                            ? '${_location.formattedCoordinates} (±${_location.accuracyMeters!.toStringAsFixed(1)}m)'
                            : '${_location.formattedCoordinates}${_location.isMock ? " (DEMO LOCATION)" : ""}',
                      ),
                      _buildDetailRow('Corridor', '${_location.locationName}, ${_location.subArea}'),
                      if (_location.accuracyMeters != null)
                        _buildDetailRow('GPS Accuracy', '±${_location.accuracyMeters!.toStringAsFixed(1)}m (Active Telemetry)'),
                      _buildDetailRow(
                        'Household Headcount',
                        _profile.isHeadcountConfigured
                            ? '${_profile.totalPeople} people (${_profile.adults ?? 0}A, ${_profile.children ?? 0}C, ${_profile.seniors ?? 0}S)'
                            : 'Not provided',
                      ),
                      if (_profile.isHeadcountConfigured) ...[
                        _buildDetailRow('Pets / Animals', '${_profile.pets ?? 0}'),
                        _buildDetailRow(
                          'Mobility Assistance',
                          _profile.needsMobilityAssistance ? 'Required (Wheelchair)' : 'Standard',
                        ),
                      ],
                      _buildDetailRow(
                        'Protocol Status',
                        _isSosTriggered ? 'SOS Triggered (Manual Dial/Share Required)' : 'Standby / Ready to Share',
                      ),
                      _buildDetailRow(
                        'Telemetry Source',
                        _location.isMock
                            ? 'Kakinada Demo Baseline (Coastal AP)'
                            : 'Device GPS Hardware (Satellite Fix)',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            ),
                          ),
                          onPressed: _sendLocationSms,
                          icon: const Icon(Icons.sms_outlined, size: 18),
                          label: Text(AppStrings.sendLocationSms),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF475569)),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            ),
                          ),
                          onPressed: _copyDetailsToClipboard,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(AppStrings.copyCoordinates),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCallButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
