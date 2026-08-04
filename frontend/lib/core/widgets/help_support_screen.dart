import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coming_soon_screen.dart';

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

/// Call and email rows open the device dialer/mail app directly; every
/// other contact method (e.g. Live Chat) still falls back to Coming Soon.
Future<void> _handleContactTap(BuildContext context, HelpContactMethod method) async {
  final Uri? uri = switch (method.icon) {
    Icons.call_rounded => Uri(scheme: 'tel', path: method.detail.replaceAll(RegExp(r'\s+'), '')),
    Icons.email_outlined => Uri(scheme: 'mailto', path: method.detail),
    _ => null,
  };

  if (uri == null) {
    _openComingSoon(context, method.label, method.icon);
    return;
  }

  var launched = false;
  try {
    launched = await launchUrl(uri);
  } catch (_) {
    launched = false;
  }

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${method.label.toLowerCase()}.')),
    );
  }
}

class HelpContactMethod {
  const HelpContactMethod({required this.icon, required this.label, required this.detail});

  final IconData icon;
  final String label;
  final String detail;
}

class HelpResourceLink {
  const HelpResourceLink({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Shared Help & Support screen: one implementation reused by every role's
/// Profile tab, parameterized with role-specific copy so a farmer, driver,
/// and buyer each see help content relevant to what they actually do in the
/// app (checklist: role-specific screens use their own data, not a
/// one-size-fits-all placeholder).
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({
    super.key,
    required this.roleLabel,
    required this.heroSubtitle,
    required this.contactMethods,
    required this.faqItems,
    required this.resourceLinks,
    this.onNotificationsTap,
  });

  final String roleLabel;
  final String heroSubtitle;
  final List<HelpContactMethod> contactMethods;
  final List<String> faqItems;
  final List<HelpResourceLink> resourceLinks;
  final VoidCallback? onNotificationsTap;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final faqItems = query.isEmpty
        ? widget.faqItems
        : widget.faqItems.where((q) => q.toLowerCase().contains(query)).toList();

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      shape: const CircleBorder(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Help & Support',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onNotificationsTap ??
                        () => _openComingSoon(context, 'Notifications', Icons.notifications_none_rounded),
                    icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  hintText: 'Search for topics or questions...',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              _HeroCard(colorScheme: colorScheme, subtitle: widget.heroSubtitle),
              const SizedBox(height: 28),
              Text(
                'Contact Support',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                colorScheme: colorScheme,
                children: [
                  for (var i = 0; i < widget.contactMethods.length; i++)
                    _ContactRow(
                      colorScheme: colorScheme,
                      method: widget.contactMethods[i],
                      isLast: i == widget.contactMethods.length - 1,
                      onTap: () => _handleContactTap(context, widget.contactMethods[i]),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Frequently Asked Questions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openComingSoon(context, 'All FAQs', Icons.quiz_outlined),
                    child: Text(
                      'See All',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (faqItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No questions match your search.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
                  ),
                )
              else
                _InfoCard(
                  colorScheme: colorScheme,
                  children: [
                    for (var i = 0; i < faqItems.length; i++)
                      _FaqRow(
                        colorScheme: colorScheme,
                        question: faqItems[i],
                        isLast: i == faqItems.length - 1,
                        onTap: () => _openComingSoon(context, faqItems[i], Icons.quiz_outlined),
                      ),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                'Resources & Legal',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                colorScheme: colorScheme,
                children: [
                  for (var i = 0; i < widget.resourceLinks.length; i++)
                    _ResourceRow(
                      colorScheme: colorScheme,
                      link: widget.resourceLinks[i],
                      isLast: i == widget.resourceLinks.length - 1,
                      onTap: () => _openComingSoon(context, widget.resourceLinks[i].label, widget.resourceLinks[i].icon),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Text(
                      'AgriConnect v2.4.0',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Made with ❤️ for ${widget.roleLabel}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.colorScheme, required this.subtitle});

  final ColorScheme colorScheme;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Blended rather than the raw (very pale) tertiary token — a
            // full-strength stop there washes out the white text it sits
            // under; this keeps the same light-green direction while
            // staying legible.
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.65)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(Icons.support_agent_rounded, size: 140, color: Colors.white.withValues(alpha: 0.12)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'How can we help you today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5, height: 1.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.colorScheme, required this.children});

  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.colorScheme, required this.method, required this.onTap, this.isLast = false});

  final ColorScheme colorScheme;
  final HelpContactMethod method;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(method.icon, color: colorScheme.primary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(method.detail, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.colorScheme, required this.question, required this.onTap, this.isLast = false});

  final ColorScheme colorScheme;
  final String question;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: colorScheme.onSurfaceVariant, size: 19),
            const SizedBox(width: 14),
            Expanded(
              child: Text(question, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14.5)),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.colorScheme, required this.link, required this.onTap, this.isLast = false});

  final ColorScheme colorScheme;
  final HelpResourceLink link;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Icon(link.icon, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(link.label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Icon(Icons.open_in_new_rounded, color: colorScheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
