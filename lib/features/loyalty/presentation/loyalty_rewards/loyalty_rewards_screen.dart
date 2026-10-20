import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'loyalty_rewards_controller.dart';
import '../widgets/loyalty_progress_section.dart';
import '../widgets/loyalty_stamp_grid.dart';

/// "Mes récompenses" — destination for the sheet's "Voir mes récompenses"
/// button. Shows the customer's confirmed progress in the current 10-order
/// cycle (no pending-order awareness — this is a static snapshot, unlike the
/// transient post-order sheet).
///
/// UI only: the cycle position and the milestone states come from
/// [LoyaltyRewardsController].
class LoyaltyRewardsScreen extends ConsumerWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cycleAsync = ref.watch(loyaltyRewardsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.loyaltyRewardsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: cycleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: ElevatedButton.icon(
            onPressed: ref.read(loyaltyRewardsControllerProvider.notifier).retry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        data: (cycle) => _RewardsBody(l10n: l10n, cycle: cycle),
      ),
    );
  }
}

class _RewardsBody extends StatelessWidget {
  final AppLocalizations l10n;
  final LoyaltyCycle cycle;
  const _RewardsBody({required this.l10n, required this.cycle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(l10n: l10n, cycle: cycle),
          const SizedBox(height: 20),
          _MilestonesSection(l10n: l10n, cycle: cycle),
          const SizedBox(height: 20),
          _HowItWorksSection(l10n: l10n),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppLocalizations l10n;
  final LoyaltyCycle cycle;
  const _HeaderCard({required this.l10n, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final remainingText = cycle.halfAchieved
        ? l10n.loyaltyRemainingFree(cycle.remainingToFree)
        : l10n.loyaltyRemainingHalf(cycle.remainingToHalf);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppColors.loyaltyHeaderGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.loyaltyDecorCircleAmber),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.loyaltyDecorCircleWhite),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: Image.asset('assets/images/logo_client.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.loyaltyRewardsTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LoyaltyStampGrid(
                  earnedCount: cycle.position,
                  totalSlots: cycle.totalSlots,
                  staggerIn: true,
                ),
              ),
              const SizedBox(height: 16),
              LoyaltyProgressSection(
                l10n: l10n,
                filled: cycle.position,
                total: cycle.totalSlots,
                remainingText: remainingText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestonesSection extends StatelessWidget {
  final AppLocalizations l10n;
  final LoyaltyCycle cycle;
  const _MilestonesSection({required this.l10n, required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MilestoneCard(
          icon: Icons.percent_rounded,
          title: l10n.loyaltyMilestoneHalfTitle,
          subtitle: l10n.loyaltyMilestoneHalfSubtitle,
          state: cycle.halfMilestone,
          l10n: l10n,
        ),
        const SizedBox(height: 10),
        _MilestoneCard(
          icon: Icons.card_giftcard_rounded,
          title: l10n.loyaltyMilestoneFreeTitle,
          subtitle: l10n.loyaltyMilestoneFreeSubtitle,
          state: cycle.freeMilestone,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LoyaltyMilestoneState state;
  final AppLocalizations l10n;

  const _MilestoneCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color iconColor;
    final String label;
    switch (state) {
      case LoyaltyMilestoneState.achieved:
        bg = AppColors.loyaltyMilestoneAchievedBg;
        border = AppColors.loyaltyMilestoneAchievedBorder;
        iconColor = AppColors.loyaltyStampEarnedBorder;
        label = l10n.loyaltyStateAchieved;
      case LoyaltyMilestoneState.current:
        bg = AppColors.loyaltyMilestoneCurrentBg;
        border = AppColors.loyaltyMilestoneCurrentBorder;
        iconColor = AppColors.loyaltyStampPendingIcon;
        label = l10n.loyaltyStateCurrent;
      case LoyaltyMilestoneState.locked:
        bg = AppColors.loyaltyMilestoneLockedBg;
        border = AppColors.loyaltyMilestoneLockedBorder;
        iconColor = AppColors.loyaltyMilestoneLockedIcon;
        label = l10n.loyaltyStateLocked;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.7)),
            child: Icon(
              state == LoyaltyMilestoneState.achieved ? Icons.check_rounded : icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  final AppLocalizations l10n;
  const _HowItWorksSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final bullets = [
      l10n.loyaltyHowItWorks1,
      l10n.loyaltyHowItWorks2,
      l10n.loyaltyHowItWorks3,
      l10n.loyaltyHowItWorks4,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.loyaltyCancelMiniCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.loyaltyHowItWorksTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
