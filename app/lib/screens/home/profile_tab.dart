import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../onboarding/onboarding_flow.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.data});

  final OnboardingData data;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _faceIdBusy = false;
  bool _statusBusy = false;

  Future<void> _editStatus() async {
    final controller = TextEditingController(text: widget.data.statusText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set your status'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'e.g. Ready for the next trip ✈️'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Not disposing `controller` here deliberately — the dialog's exit
    // transition can still be rendering a frame bound to it right after
    // this await resolves, and disposing while that frame renders throws
    // ("TextEditingController used after being disposed") and corrupts
    // the Profile tab's widget tree. It's a short-lived, one-shot
    // controller with nothing left referencing it once this returns, so
    // leaving it for GC instead of an explicit dispose() is safe here.
    if (result == null) return;

    final trimmed = result.trim();
    setState(() => _statusBusy = true);
    try {
      await AuthService.instance.setStatusText(trimmed);
      setState(() => widget.data.statusText = trimmed);
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _toggleFaceId(bool enable) async {
    if (enable) {
      final available = await BiometricService.instance.isAvailable();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face ID isn\'t set up on this device.')),
        );
        return;
      }
      final confirmed = await BiometricService.instance.authenticate(reason: 'Enable Face ID for Waypoint');
      if (!confirmed) return;
    }
    setState(() => _faceIdBusy = true);
    try {
      await AuthService.instance.setFaceIdEnabled(enable);
      setState(() => widget.data.faceIdEnabled = enable);
    } finally {
      if (mounted) setState(() => _faceIdBusy = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final address = [
      data.street,
      data.apt,
      data.city,
      [data.state, data.zip].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle),
                  child: Text(
                    data.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.fullName.isEmpty ? 'Jamie Rivera' : data.fullName,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _statusBusy ? null : _editStatus,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_statusBusy)
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        else
                          Icon(Icons.edit_outlined, size: 13, color: context.colors.textTertiary),
                        const SizedBox(width: 5),
                        Text(
                          data.statusText.isEmpty ? 'Add a status' : data.statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: data.statusText.isEmpty ? FontStyle.italic : FontStyle.normal,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _InfoRow(label: 'Email', value: data.email.isEmpty ? 'Not added yet' : data.email),
          _InfoRow(label: 'Phone', value: data.phone.isEmpty ? 'Not added yet' : data.phone),
          _InfoRow(label: 'Home address', value: address.isEmpty ? 'Not added yet' : address),
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.divider))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FACE ID'.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text('Skip sign-in on relaunch', style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
                    ],
                  ),
                ),
                _faceIdBusy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                        value: data.faceIdEnabled,
                        activeThumbColor: context.colors.accent,
                        onChanged: _toggleFaceId,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
        ],
      ),
    );
  }
}
