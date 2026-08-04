import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/responsive_content.dart';
import '../application/orders_providers.dart';
import '../data/orders_mock.dart';
import 'confirm_delivery_screen.dart';

Future<void> _callNumber(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (!await launchUrl(uri)) {
    if (context.mounted) showAgriToast(context, 'Could not open the phone app.');
  }
}

Future<void> _textNumber(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'sms', path: phone);
  if (!await launchUrl(uri)) {
    if (context.mounted) showAgriToast(context, 'Could not open the messaging app.');
  }
}

void _openComingSoon(BuildContext context, String title, IconData icon) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ComingSoonScreen(
        title: title,
        icon: icon,
        message: '$title will be available in a future update.',
      ),
    ),
  );
}

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Live tracking for an in-transit shipment: status + route map with the
/// driver's contact card (when one's actually assigned), delivery details,
/// an escrow reminder, and a Confirm Arrival action that runs the same real
/// QR-based confirm-delivery flow as the Orders screen — this used to just
/// show a "thank you" toast and pop without calling the backend at all, so
/// "confirming" here silently left the order stuck and payment unreleased.
/// Pushed from the Active Shipment card's map button (orders_screen.dart).
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.shipment});

  final ActiveShipment shipment;

  Future<void> _confirmArrival(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(transactionId: shipment.id)),
    );
    if (result == true) {
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        showAgriToast(context, 'Delivery confirmed — payment released to the farmer.');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pickup = shipment.farmerLocation ?? 'Farm pickup location';
    const dropoff = 'Your delivery address';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: ResponsiveContent(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        colorScheme: colorScheme,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Order Tracking',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _RoundIconButton(
                        icon: Icons.help_outline_rounded,
                        colorScheme: colorScheme,
                        onTap: () => _openComingSoon(context, 'Help & Support', Icons.help_outline_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _TrackingCard(colorScheme: colorScheme, shipment: shipment),
                      const SizedBox(height: 24),
                      Text(
                        'Delivery Details',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _DeliveryDetailsCard(colorScheme: colorScheme, pickup: pickup, dropoff: dropoff),
                      const SizedBox(height: 16),
                      _EscrowNotice(colorScheme: colorScheme),
                    ],
                  ),
                ),
                _ConfirmArrivalBar(
                  colorScheme: colorScheme,
                  total: shipment.escrowTotal,
                  onConfirm: () => _confirmArrival(context, ref),
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.colorScheme, required this.onTap});

  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.colorScheme, required this.shipment});

  final ColorScheme colorScheme;
  final ActiveShipment shipment;

  @override
  Widget build(BuildContext context) {
    // No live GPS/ETA data exists anywhere in the system, so this shows the
    // real order status rather than a fabricated "arriving in N mins".
    final driverAssigned = shipment.driverName != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${shipment.orderNumber}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shipment.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                shipment.status.label.toUpperCase(),
                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressTrack(colorScheme: colorScheme, progress: 1),
          const SizedBox(height: 10),
          if (!shipment.hasOwnTransport) ...[
            _ProgressTrack(colorScheme: colorScheme, progress: driverAssigned ? 1 : 0),
            const SizedBox(height: 18),
          ],
          _MapPreview(shipment: shipment),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.colorScheme, required this.progress});

  final ColorScheme colorScheme;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: 6,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.shipment});

  final ActiveShipment shipment;

  @override
  Widget build(BuildContext context) {
    final routeColor = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _RouteMapPainter(routeColor: routeColor)),
            Positioned(left: 10, right: 10, bottom: 10, child: _DriverCard(shipment: shipment)),
          ],
        ),
      ),
    );
  }
}

/// Decorative stand-in for a real map SDK (none is wired up yet) — a soft
/// street grid with a highlighted route line, so the tracking card reads
/// as "a map" without pretending to show real tiles or attribution.
class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({required this.routeColor});

  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE7ECE4));

    final diagonalStreet = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    for (final t in [0.15, 0.4, 0.65, 0.88]) {
      canvas.drawLine(
        Offset(0, size.height * t),
        Offset(size.width, size.height * (t - 0.12).clamp(0, 1)),
        diagonalStreet,
      );
    }

    final crossStreet = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    for (final t in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(size.width * t, 0), Offset(size.width * t, size.height), crossStreet);
    }

    final routeStart = Offset(size.width * 0.14, size.height * 0.85);
    final routeEnd = Offset(size.width * 0.82, size.height * 0.2);
    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(routeStart.dx, routeStart.dy)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.75, routeEnd.dx, routeEnd.dy);
    canvas.drawPath(path, routePaint);

    canvas.drawCircle(routeStart, 6, Paint()..color = routeColor);
    canvas.drawCircle(routeEnd, 10, Paint()..color = Colors.white);
    canvas.drawCircle(routeEnd, 6, Paint()..color = routeColor);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) => oldDelegate.routeColor != routeColor;
}

/// Three honest states, no invented driver identity, rating, or vehicle
/// (none of that data exists anywhere in the system): self-collect orders
/// never had a driver to begin with; driver-assisted orders show a real
/// "waiting for a driver" state until one actually accepts the job, then
/// show that driver's real name.
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.shipment});

  final ActiveShipment shipment;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (shipment.hasOwnTransport) {
      return _StatusCard(
        icon: Icons.storefront_rounded,
        primary: primary,
        text: "You're picking this up yourself — no driver needed.",
      );
    }

    final driverName = shipment.driverName;
    if (driverName == null) {
      return _StatusCard(
        icon: Icons.hourglass_top_rounded,
        primary: primary,
        text: 'Waiting for a driver to accept this delivery.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primary,
                child: Text(
                  _initialsOf(driverName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _textNumber(context, shipment.driverPhone ?? ''),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.sms_outlined, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _callNumber(context, shipment.driverPhone ?? ''),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                  child: const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.primary, required this.text});

  final IconData icon;
  final Color primary;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Icon(icon, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryDetailsCard extends StatelessWidget {
  const _DeliveryDetailsCard({required this.colorScheme, required this.pickup, required this.dropoff});

  final ColorScheme colorScheme;
  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DetailRow(
            colorScheme: colorScheme,
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF2E7D32),
            label: 'Pickup Location',
            value: pickup,
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.15)),
          _DetailRow(
            colorScheme: colorScheme,
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFFF9A825),
            label: 'Delivery Address',
            value: dropoff,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.colorScheme,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowNotice extends StatelessWidget {
  const _EscrowNotice({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final info = AgriStatusColors.info(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: info.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: info, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payment is held securely in Escrow. Funds are only released to the farmer once you confirm delivery.',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmArrivalBar extends StatelessWidget {
  const _ConfirmArrivalBar({required this.colorScheme, required this.total, required this.onConfirm});

  final ColorScheme colorScheme;
  final double total;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onConfirm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total Amount', style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.85), fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(
                        formatGhs(total),
                        style: TextStyle(color: colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text('Scan to Confirm', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
