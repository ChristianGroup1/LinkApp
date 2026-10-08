import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/member_location.dart';
import '../member_maps_support.dart';

/// OpenStreetMap view for a served member. Tests use a static card so they
/// do not download tiles.
class MemberLocationMap extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final bool interactive;
  final ValueChanged<MemberLocation>? onPick;
  final VoidCallback? onOpen;
  final double height;
  final bool expand;

  const MemberLocationMap({
    super.key,
    this.latitude,
    this.longitude,
    this.interactive = false,
    this.onPick,
    this.onOpen,
    this.height = 190,
    this.expand = false,
  });

  @override
  State<MemberLocationMap> createState() => _MemberLocationMapState();
}

class _MemberLocationMapState extends State<MemberLocationMap> {
  final MapController _controller = MapController();
  bool _ready = false;
  LatLng? _localPoint;

  @override
  void initState() {
    super.initState();
    _localPoint = _pointFrom(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(MemberLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _pointFrom(widget.latitude, widget.longitude);
    if (next == null || next == _localPoint) return;
    _localPoint = next;
    if (_ready) _controller.move(next, 16);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = MemberLocation.fromNumbers(
      widget.latitude,
      widget.longitude,
    );
    if (!useLiveMemberMap) {
      return _frame(
        _MemberMapFallback(
          location: location,
          interactive: widget.interactive,
          onOpen: widget.onOpen,
        ),
      );
    }

    final target =
        _localPoint ??
        const LatLng(
          MemberLocation.defaultLatitude,
          MemberLocation.defaultLongitude,
        );
    return _frame(
      Semantics(
        label: 'خريطة موقع المخدوم',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlutterMap(
            key: const Key('member-location-map'),
            mapController: _controller,
            options: MapOptions(
              initialCenter: target,
              initialZoom: location == null ? 12 : 16,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _ready = true;
                final point = _localPoint;
                if (point != null) _controller.move(point, 16);
              },
              onTap: (event, point) {
                if (widget.interactive) {
                  _select(point);
                } else {
                  widget.onOpen?.call();
                }
              },
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MemberLocation.tileUrlTemplate,
                userAgentPackageName: MemberLocation.userAgentPackageName,
              ),
              if (location != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 44,
                      height: 44,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onPanUpdate: widget.interactive
                            ? (details) => _dragPin(
                                LatLng(location.latitude, location.longitude),
                                details.delta,
                              )
                            : null,
                        child: const Icon(
                          Icons.location_on,
                          color: AppTheme.accentRed,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),
              const _OsmAttribution(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(Widget child) {
    if (widget.expand) return SizedBox.expand(child: child);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: child,
    );
  }

  void _select(LatLng point) {
    _localPoint = point;
    widget.onPick?.call(
      MemberLocation(latitude: point.latitude, longitude: point.longitude),
    );
  }

  void _dragPin(LatLng origin, Offset delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    final current = camera.latLngToScreenOffset(origin);
    _select(camera.screenOffsetToLatLng(current + delta));
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ColoredBox(
        color: const Color(0xE6FFFFFF),
        child: GestureDetector(
          onTap: () => unawaited(
            launchUrl(
              MemberLocation.copyrightUri,
              mode: LaunchMode.externalApplication,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              '© OpenStreetMap contributors',
              style: GoogleFonts.cairo(
                color: const Color(0xFF1F2937),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberMapFallback extends StatelessWidget {
  final MemberLocation? location;
  final bool interactive;
  final VoidCallback? onOpen;

  const _MemberMapFallback({
    required this.location,
    required this.interactive,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final coordinates = location == null
        ? null
        : '${formatMemberCoordinate(location!.latitude)}، ${formatMemberCoordinate(location!.longitude)}';
    return Semantics(
      label: coordinates == null
          ? 'الخريطة غير متاحة'
          : 'موقع المخدوم $coordinates',
      button: onOpen != null,
      child: Material(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('member-location-map'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: AppTheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  coordinates ?? 'الخريطة غير متاحة الآن',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  interactive
                      ? 'اضغط على الخريطة لوضع الدبوس أو اسحبه، أو استخدم موقعك الحالي.'
                      : 'يمكنك فتح الموقع في خرائط جوجل.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

LatLng? _pointFrom(double? latitude, double? longitude) {
  final location = MemberLocation.fromNumbers(latitude, longitude);
  if (location == null) return null;
  return LatLng(location.latitude, location.longitude);
}
