import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

/// The vertical list of steps on the tracking screen (✔ Confirmée →
/// En préparation / Prête → En route → Livrée), done steps in green.
/// Different steps for parcels and bill payments.
class OrderTimeline extends StatelessWidget {
  final OrderStatus status;
  final bool isCourier;
  final bool isFacture;

  /// Le commerçant prépare-t-il la commande avant qu'elle soit prête ?
  ///
  /// Vrai pour les restaurants seulement. Partout ailleurs le commerçant met
  /// de côté ce qu'il a en rayon : la commande passe d'« acceptée » à
  /// « prête », et annoncer une préparation au client décrivait un travail
  /// qui n'a pas lieu. La valeur vient de `vendor_categories`, la même ligne
  /// que lisent l'application partenaire et celle du livreur.
  final bool hasPreparationStep;

  const OrderTimeline({
    super.key,
    required this.status,
    this.isCourier = false,
    this.isFacture = false,
    this.hasPreparationStep = true,
  });

  @override
  Widget build(BuildContext context) {
    final steps = isFacture
        ? [
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineOrderConfirmed,
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineDriverComing,
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.directions_bike,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineCashCollected,
              isCompleted: status.index >= OrderStatus.pickedUp.index,
              icon: Icons.payments_rounded,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineBillPaid,
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.receipt_long_rounded,
            ),
          ]
        : isCourier
        ? [
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineRequestConfirmed,
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelinePickedUp,
              isCompleted: status.index >= OrderStatus.pickedUp.index ||
                  status == OrderStatus.onTheWay ||
                  status == OrderStatus.delivered,
              icon: Icons.inventory_2,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineOnTheWay,
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.local_shipping,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineDelivered,
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ]
        : [
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineOrderConfirmed,
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            // Le restaurant prépare ; le fleuriste, l'épicier ou le magasin
            // d'électronique met de côté et annonce « prête ». Deux étapes
            // différentes, pas un habillage de la même.
            if (hasPreparationStep)
              _TimelineStep(
                title: AppLocalizations.of(context)!.timelinePreparing,
                isCompleted: status.index >= OrderStatus.preparing.index,
                icon: Icons.restaurant,
              )
            else
              _TimelineStep(
                title: AppLocalizations.of(context)!.timelineReady,
                isCompleted: status.index >= OrderStatus.ready.index,
                icon: Icons.inventory_2_rounded,
              ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineOnTheWay,
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.delivery_dining,
            ),
            _TimelineStep(
              title: AppLocalizations.of(context)!.timelineDelivered,
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ];

    return Column(
      children: List.generate(
        steps.length,
        (index) => _TimelineItem(step: steps[index], isLast: index == steps.length - 1),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final bool isCompleted;
  final IconData icon;

  _TimelineStep({required this.title, required this.isCompleted, required this.icon});
}

class _TimelineItem extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineItem({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: step.isCompleted ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.isCompleted ? AppColors.primary : AppColors.textLight,
                  width: 2,
                ),
              ),
              child: Icon(
                step.icon,
                color: step.isCompleted ? Colors.white : AppColors.textLight,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted
                    ? AppColors.primary
                    : AppColors.textLight.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            step.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: step.isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: step.isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
