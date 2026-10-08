import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/member_device_location.dart';
import '../data/member_location.dart';
import 'widgets/member_location_map.dart';

/// Full-screen picker: tap or drag a pin, or use the device location.
class MemberLocationPickerScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const MemberLocationPickerScreen({super.key, this.latitude, this.longitude});

  @override
  State<MemberLocationPickerScreen> createState() =>
      _MemberLocationPickerScreenState();
}

class _MemberLocationPickerScreenState
    extends State<MemberLocationPickerScreen> {
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.latitude;
    _longitude = widget.longitude;
  }

  bool get _hasPin => _latitude != null && _longitude != null;

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final location = await readCurrentMemberLocation();
      if (!mounted) return;
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _isLocating = false;
      });
    } on MemberLocationException catch (error) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.cardBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'تحديد الموقع',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: MemberLocationMap(
                  latitude: _latitude,
                  longitude: _longitude,
                  interactive: true,
                  expand: true,
                  onPick: (location) => setState(() {
                    _latitude = location.latitude;
                    _longitude = location.longitude;
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _hasPin
                        ? 'الموقع: ${formatMemberCoordinate(_latitude!)}، ${formatMemberCoordinate(_longitude!)}'
                        : 'اضغط على الخريطة لوضع الدبوس، أو استخدم موقعك الحالي.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      'استخدام موقعي الحالي',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _hasPin
                        ? () => Navigator.pop(
                            context,
                            MemberLocationPick(
                              latitude: _latitude,
                              longitude: _longitude,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      'تأكيد الموقع',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                  if (_hasPin)
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        const MemberLocationPick.cleared(),
                      ),
                      child: Text(
                        'إزالة الموقع',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentRed,
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
