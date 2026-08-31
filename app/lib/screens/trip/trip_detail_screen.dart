import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../services/auth_service.dart';
import '../../services/eta_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/trip_cover_art.dart';
import 'chat_screen.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool get _isTripDay => widget.trip.status == TripStatus.upcoming && widget.trip.daysLeft == 0;

  List<MemberEta> _etas = const [];
  bool _loadingEtas = false;
  bool _sharing = false;
  int? _myEtaMinutes;
  EtaUnavailableReason? _shareError;

  @override
  void initState() {
    super.initState();
    if (_isTripDay) _loadEtas();
  }

  Future<void> _loadEtas() async {
    setState(() => _loadingEtas = true);
    final etas = await EtaService.instance.fetchEtas(widget.trip.id);
    if (!mounted) return;
    setState(() {
      _etas = etas;
      _loadingEtas = false;
    });
  }

  Future<void> _shareMyEta() async {
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    // loadProfile() doesn't catch its own network errors — a failed
    // lookup here shouldn't block sharing an ETA, just fall back to a
    // generic label.
    String displayName = 'You';
    try {
      final profile = await AuthService.instance.loadProfile();
      if (profile.fullName.isNotEmpty) displayName = profile.fullName;
    } catch (_) {
      // fall back to 'You'
    }
    final result = await EtaService.instance.computeAndShareMyEta(
      tripId: widget.trip.id,
      destination: widget.trip.destination,
      displayName: displayName,
    );
    if (!mounted) return;
    setState(() {
      _sharing = false;
      if (result.succeeded) {
        _myEtaMinutes = result.etaMinutes;
      } else {
        _shareError = result.reason;
      }
    });
    if (result.succeeded) await _loadEtas();
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(trip: widget.trip)));
  }

  void _startNavigation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("This would open your maps app for turn-by-turn directions.")),
    );
  }

  String _errorMessage(EtaUnavailableReason reason) {
    switch (reason) {
      case EtaUnavailableReason.permissionDenied:
        return "Location access is off — enable it in Settings to share your ETA.";
      case EtaUnavailableReason.locationServicesOff:
        return "Location services are off on this device.";
      case EtaUnavailableReason.locationFailed:
        return "Couldn't get your current location — try again.";
      case EtaUnavailableReason.geocodeFailed:
        return "Couldn't find the trip destination on the map.";
      case EtaUnavailableReason.notSignedIn:
        return "Sign in again to share your ETA.";
      case EtaUnavailableReason.syncFailed:
        return "Computed your ETA, but couldn't share it — try again.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: context.colors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openChat(context),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TripCoverArt(trip: trip),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.7)],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text('${trip.daysLeft}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)),
                          const Text('days left', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              '${trip.destination} · ${trip.dateLabel}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 19, top: 3),
                          child: Text(
                            'ETA ${trip.etaLabel}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startNavigation(context),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.navigation_outlined, size: 18, color: Colors.white),
                        SizedBox(height: 2),
                        Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('Get directions', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Color(0xFFCB9A2E)),
                        const SizedBox(height: 2),
                        Text(trip.weatherTemp, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                        Text(trip.weatherCondition, style: TextStyle(fontSize: 10.5, color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isTripDay) ...[
              const SizedBox(height: 24),
              _EtaSection(
                trip: trip,
                etas: _etas,
                loading: _loadingEtas,
                sharing: _sharing,
                myEtaMinutes: _myEtaMinutes,
                errorMessage: _shareError == null ? null : _errorMessage(_shareError!),
                onShare: _shareMyEta,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                Text('${trip.members.length + 1} total', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            _MemberRow(name: 'You (Admin)', initials: 'ME', status: MemberStatus.admin, distance: '—'),
            for (final member in trip.members)
              _MemberRow(name: member.name, initials: member.initials, status: member.status, distance: member.distance),
          ],
        ),
      ),
    );
  }
}

class _EtaSection extends StatelessWidget {
  const _EtaSection({
    required this.trip,
    required this.etas,
    required this.loading,
    required this.sharing,
    required this.myEtaMinutes,
    required this.errorMessage,
    required this.onShare,
  });

  final Trip trip;
  final List<MemberEta> etas;
  final bool loading;
  final bool sharing;
  final int? myEtaMinutes;
  final String? errorMessage;
  final VoidCallback onShare;

  String _formatEta(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  String _formatAge(DateTime computedAt) {
    final age = DateTime.now().difference(computedAt);
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final everyone = ['You', ...trip.members.map((m) => m.name)];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.accentTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.near_me_outlined, size: 16, color: context.colors.accent),
              const SizedBox(width: 8),
              Text("Today's ETAs", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Share your live location once — this doesn't track in the background.",
            style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sharing ? null : onShare,
              icon: sharing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location_rounded, size: 16),
              label: Text(myEtaMinutes == null ? 'Share my ETA' : 'Update my ETA (${_formatEta(myEtaMinutes!)})'),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(errorMessage!, style: const TextStyle(fontSize: 11.5, color: Colors.red)),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            for (final name in everyone)
              Builder(
                builder: (context) {
                  final eta = etas.where((e) => e.displayName == name).firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: TextStyle(fontSize: 12.5, color: context.colors.textPrimary)),
                        Text(
                          eta == null ? 'Not shared yet' : '${_formatEta(eta.etaMinutes)} · ${_formatAge(eta.computedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: eta == null ? FontWeight.normal : FontWeight.w700,
                            color: eta == null ? context.colors.textTertiary : context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.initials, required this.status, required this.distance});

  final String name;
  final String initials;
  final MemberStatus status;
  final String distance;

  (Color, Color, String) _badge(BuildContext context) {
    switch (status) {
      case MemberStatus.admin:
        return (context.colors.accentTint, context.colors.accent, 'Admin');
      case MemberStatus.member:
        return (context.colors.successBg, context.colors.success, 'Member');
      case MemberStatus.invited:
        return (context.colors.pendingBg, context.colors.textSecondary, 'Invited');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _badge(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.accentTint, shape: BoxShape.circle),
            child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
                    ),
                  ],
                ),
                Text('$distance from home', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
