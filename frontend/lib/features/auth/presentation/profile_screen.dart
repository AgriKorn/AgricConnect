import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/agri_button.dart';
import '../../../core/widgets/agri_card.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../data/models/user_role.dart';

/// Shared Profile tab across all three roles. Houses profile details
/// (role-specific fields, backed by GET/PATCH /users/profile), the
/// dark/light/system toggle, and Logout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _farmRegionController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _truckCapacityController = TextEditingController();
  final _operatingRegionController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _farmRegionController.dispose();
    _businessNameController.dispose();
    _deliveryAddressController.dispose();
    _truckCapacityController.dispose();
    _operatingRegionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(authRepositoryProvider).fetchProfile();
      if (!mounted) return;
      _farmRegionController.text = profile.farmRegion ?? '';
      _businessNameController.text = profile.businessName ?? '';
      _deliveryAddressController.text = profile.deliveryAddress ?? '';
      _truckCapacityController.text = profile.truckCapacity?.toStringAsFixed(0) ?? '';
      _operatingRegionController.text = profile.operatingRegion ?? '';
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(UserRole role) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fields = switch (role) {
        UserRole.farmer => {'farmRegion': _farmRegionController.text.trim()},
        UserRole.buyer => {
            'businessName': _businessNameController.text.trim(),
            'deliveryAddress': _deliveryAddressController.text.trim(),
          },
        UserRole.driver => {
            'truckCapacity': double.tryParse(_truckCapacityController.text.trim()) ?? 0,
            'operatingRegion': _operatingRegionController.text.trim(),
          },
        UserRole.admin => <String, dynamic>{},
      };
      await ref.read(authRepositoryProvider).updateProfile(fields);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = ref.watch(authControllerProvider);
    final user = session.user;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AgriCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Unknown', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '', style: Theme.of(context).textTheme.bodyMedium),
                        if (user != null) ...[
                          const SizedBox(height: 2),
                          Text(user.role.label, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (user != null && user.role != UserRole.admin) ...[
              Text('Profile Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              AgriCard(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._fieldsFor(user.role),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 8),
                          AgriButton(
                            label: _saving ? 'Saving...' : 'Save Changes',
                            loading: _saving,
                            onPressed: () => _save(user.role),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            AgriCard(
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    ref.read(themeModeControllerProvider.notifier).setThemeMode(selection.first),
              ),
            ),
            const SizedBox(height: 24),
            AgriButton(
              label: 'Log Out',
              variant: AgriButtonVariant.destructive,
              onPressed: () async {
                final confirmed = await showAgriDialog(
                  context,
                  title: 'Log out?',
                  message: "You'll need to log in again to access your account.",
                  confirmLabel: 'Log Out',
                  destructive: true,
                );
                if (confirmed == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldsFor(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return [_field('Farm Region', _farmRegionController)];
      case UserRole.buyer:
        return [
          _field('Business Name', _businessNameController),
          const SizedBox(height: 12),
          _field('Delivery Address', _deliveryAddressController),
        ];
      case UserRole.driver:
        return [
          _field('Truck Capacity (kg)', _truckCapacityController, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _field('Operating Region', _operatingRegionController),
        ];
      case UserRole.admin:
        return const [];
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
