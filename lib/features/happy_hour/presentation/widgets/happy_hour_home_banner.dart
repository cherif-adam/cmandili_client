import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/happy_hour_provider.dart';
import '../happy_hour_screen.dart';

const Color _kHappyOrange = Color(0xFFFF9500);
const Color _kLiveRed = Color(0xFFE53935);

/// Home-screen Happy Hour entry point.
///
/// The banner used to be a static picture that read the same whether zero or
/// twenty deals were running, so a customer had no way to know a happy hour
/// was actually on. It now says so: a pulsing LIVE badge, the real deal count
/// and best discount, a countdown to the soonest deadline, and a row of the
/// live deals right under it, so they are visible without tapping through.
class HappyHourHomeBanner extends ConsumerWidget {
  const HappyHourHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final sw = size.width;
    final sh = size.height;

    final deals = ref.watch(happyHourLiveDealsProvider);
    final isLive = deals.isNotEmpty;
    final bestPercent = deals.fold<int>(
      0,
      (best, d) => d.percentOff > best ? d.percentOff : best,
    );
    final soonestEnd = deals
        .map((d) => d.endsAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

    void openDeals({int tab = 0}) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HappyHourScreen(initialTab: tab)),
        );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.05,
        vertical: sh * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: openDeals,
            child: Container(
              height: sh * 0.17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kHappyOrange.withValues(alpha: isLive ? 0.5 : 0.25),
                    blurRadius: isLive ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/happy_hour_banner.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.2),
                        errorBuilder: (context, error, stackTrace) =>
                            const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFCC00), _kHappyOrange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.happyHourOverlayGradient,
                        ),
                      ),
                    ),
                    // With nothing running the banner is toned down, so the
                    // live state is the one that pops.
                    if (!isLive)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLive) ...[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _LivePill(label: l.happyHourLive),
                                      if (soonestEnd != null)
                                        _CountdownChip(endsAt: soonestEnd),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  l.happyHour,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: sw * 0.055,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLive
                                      ? l.happyHourDealsSummary(
                                          deals.length, bestPercent)
                                      : l.happyHourNoDealsNow,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: sw * 0.034,
                                    fontWeight: isLive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l.viewDeals,
                              style: const TextStyle(
                                color: _kHappyOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isLive) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: deals.length > 10 ? 10 : deals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _DealCard(
                  deal: deals[i],
                  onTap: () => openDeals(tab: deals[i].tab),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Red "LIVE" badge with a softly pulsing dot — the cue people already read
/// as "happening right now".
class _LivePill extends StatefulWidget {
  final String label;
  const _LivePill({required this.label});

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kLiveRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ends in 02:57:20", ticking every second.
class _CountdownChip extends StatefulWidget {
  final DateTime endsAt;
  const _CountdownChip({required this.endsAt});

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.endsAt.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    // Icon + time only: the full "Ends in …" sentence does not fit beside
    // the LIVE badge on a phone, so it is kept for screen readers instead.
    return Semantics(
      label: AppLocalizations.of(context)!.happyHourEndsIn(time),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact deal tile for the home row: photo with the discount badge, name,
/// then the deal price over the struck-through original.
class _DealCard extends StatelessWidget {
  final HappyHourDeal deal;
  final VoidCallback onTap;
  const _DealCard({required this.deal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: deal.imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFFFF3E0),
                            child:
                                Icon(Icons.local_offer, color: _kHappyOrange),
                          )
                        : CachedNetworkImage(
                            imageUrl: deal.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFFFF3E0),
                              child:
                                  Icon(Icons.local_offer, color: _kHappyOrange),
                            ),
                          ),
                  ),
                  if (deal.percentOff > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kLiveRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '-${deal.percentOff}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${deal.dealPrice.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      color: _kLiveRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${deal.price.toStringAsFixed(2)} DT',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
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
