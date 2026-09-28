import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../providers/happy_hour_provider.dart';

/// La bannière d'accueil des offres, habillée par celui qui l'appelle.
///
/// Un seul widget pour les deux bannières — l'orange du Happy Hour et le bleu
/// des promotions. Elles ont la même structure (badge EN DIRECT, compte à
/// rebours, résumé, rangée d'offres) ; seules changent les couleurs, l'image
/// et les textes. Les dupliquer aurait garanti qu'une correction n'arrive que
/// sur l'une des deux.
///
/// La bannière ne montre que les offres de SON mode de remise. Une offre de
/// supermarché sur la bannière Happy Hour ouvrirait un écran où son onglet
/// n'existe pas.
class DealsHomeBanner extends StatelessWidget {
  const DealsHomeBanner({
    super.key,
    required this.deals,
    required this.title,
    required this.summary,
    required this.noDealsLabel,
    required this.liveLabel,
    required this.ctaLabel,
    required this.accentColor,
    required this.backgroundImage,
    required this.fallbackGradient,
    required this.overlayGradient,
    required this.onOpen,
  });

  final List<HappyHourDeal> deals;
  final String title;

  /// "3 offres · jusqu'à -40 %", construit par l'appelant depuis ses propres
  /// clés de traduction.
  final String Function(int count, int bestPercent) summary;

  final String noDealsLabel;
  final String liveLabel;
  final String ctaLabel;
  final Color accentColor;
  final String backgroundImage;
  final Gradient fallbackGradient;
  final Gradient overlayGradient;

  /// Ouvre l'écran correspondant. La catégorie est vide quand le client tape
  /// la bannière elle-même plutôt qu'une offre précise.
  final void Function(String categoryId) onOpen;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sw = size.width;
    final sh = size.height;

    final isLive = deals.isNotEmpty;
    final bestPercent = deals.fold<int>(
      0,
      (best, d) => d.percentOff > best ? d.percentOff : best,
    );
    final soonestEnd = deals
        .map((d) => d.endsAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.05,
        vertical: sh * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => onOpen(''),
            child: Container(
              height: sh * 0.17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isLive ? 0.5 : 0.25),
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
                        backgroundImage,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.2),
                        errorBuilder: (context, error, stackTrace) =>
                            DecoratedBox(
                          decoration: BoxDecoration(gradient: fallbackGradient),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: overlayGradient),
                      ),
                    ),
                    // Sans rien en cours la bannière est assourdie, pour que
                    // l'état « en direct » soit celui qui ressorte.
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
                                      _LivePill(label: liveLabel),
                                      if (soonestEnd != null)
                                        _CountdownChip(endsAt: soonestEnd),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  title,
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
                                      ? summary(deals.length, bestPercent)
                                      : noDealsLabel,
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
                              ctaLabel,
                              style: TextStyle(
                                color: accentColor,
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
                  accentColor: accentColor,
                  onTap: () => onOpen(deals[i].categoryId),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const Color _kLiveRed = Color(0xFFE53935);

/// Pastille « EN DIRECT » à point pulsant — le signal que les gens lisent
/// déjà comme « c'est en ce moment ».
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

/// « 02:57:20 », qui avance chaque seconde.
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
    // Icône + heure seulement : la phrase complète « Se termine dans … » ne
    // tient pas à côté du badge sur un téléphone, elle est donc réservée aux
    // lecteurs d'écran.
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

/// Vignette compacte pour la rangée d'accueil : photo avec la pastille de
/// remise, nom, puis le prix remisé au-dessus du prix barré.
class _DealCard extends StatelessWidget {
  final HappyHourDeal deal;
  final Color accentColor;
  final VoidCallback onTap;
  const _DealCard({
    required this.deal,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: accentColor.withValues(alpha: 0.12),
      child: Icon(Icons.local_offer, color: accentColor),
    );

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
                        ? placeholder
                        : CachedNetworkImage(
                            imageUrl: deal.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => placeholder,
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
                          color: accentColor,
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
                    style: TextStyle(
                      color: accentColor,
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
