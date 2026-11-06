import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../restaurant/presentation/restaurant_detail/open_restaurant_at_dish.dart';
import '../../data/models/search_result.dart';
import '../../providers/ai_search_provider.dart';
import 'widgets/ai_all_closed_notice.dart';
import 'widgets/ai_degraded_note.dart';
import 'widgets/ai_dish_badge.dart';
import 'widgets/ai_empty_state.dart';
import 'widgets/ai_error_view.dart';
import 'widgets/ai_image_preview.dart';
import 'widgets/ai_intent_chips.dart';
import 'widgets/ai_loading_view.dart';
import 'widgets/ai_no_results.dart';
import 'widgets/ai_search_app_bar.dart';
import 'widgets/ai_search_bar.dart';
import 'widgets/ai_search_result_card.dart';
import 'widgets/image_source_sheet.dart';

/// Full-screen AI Search experience combining Darija text search
/// and visual search (order by photo) in a single, polished UI.
///
/// Top to bottom: AiSearchAppBar, AiSearchBar, AiImagePreview (photo
/// search only), then ONE body depending on the search state:
///   loading   → AiLoadingView
///   error     → AiErrorView (grey icon, our own sentence, "Réessayer")
///   no search → AiEmptyState (example queries)
///   nothing   → AiNoResults ("Ce plat n'est pas disponible…"), or
///               AiErrorView when the search without AI found nothing
///   results   → _ResultsSection: AiDegradedNote (found without AI),
///               AiAllClosedNotice (every shop closed),
///               AiIntentChips / AiDishBadge + AiSearchResultCard list
///
/// No server text is ever displayed: every message is one of ours.
///
/// A tap on a result opens its restaurant's page at the dish
/// ([openRestaurantAtDish]).
///
/// UI only: searching, the state and the retry live in [aiSearchProvider]
/// (AiSearchNotifier, AiSearchRepository behind it). This screen keeps the
/// text field, the focus, the animations and the photo picker.
class AiSearchScreen extends ConsumerStatefulWidget {
  const AiSearchScreen({super.key});

  @override
  ConsumerState<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends ConsumerState<AiSearchScreen>
    with TickerProviderStateMixin {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shimmerController;
  late final AnimationController _fabController;

  final ImagePicker _picker = ImagePicker();

  /// A result's restaurant is being read: further taps wait for it.
  bool _openingShop = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    _shimmerController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitText() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    await ref.read(aiSearchProvider.notifier).searchByText(query);
  }

  Future<void> _onPickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      if (!mounted) return;
      await ref
          .read(aiSearchProvider.notifier)
          .searchByImage(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context)!.aiSearchErrorCouldNotOpen);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageSourceSheet(onSelect: (src) {
        Navigator.pop(ctx);
        _onPickImage(src);
      }),
    );
  }

  /// The search error in the customer's language. Never the server's text.
  static String _errorText(AppLocalizations l10n, AiSearchState state) =>
      switch (state.errorKind) {
        AiSearchErrorKind.network => l10n.aiSearchErrorNetwork,
        AiSearchErrorKind.imageTooLarge =>
          l10n.aiSearchErrorImageTooLarge(state.errorDetail ?? ''),
        AiSearchErrorKind.unavailable || null => l10n.aiSearchErrorUnavailable,
      };

  static IconData _errorIcon(AiSearchState state) => switch (state.errorKind) {
        AiSearchErrorKind.network => Icons.wifi_off_rounded,
        AiSearchErrorKind.imageTooLarge => Icons.photo_size_select_large_rounded,
        AiSearchErrorKind.unavailable || null => Icons.cloud_off_rounded,
      };

  /// Opens [item]'s restaurant page, scrolled to the dish. A closed
  /// restaurant opens too: its page shows it closed and blocks the cart.
  Future<void> _openShop(AiSearchFoodResult item) async {
    if (_openingShop) return;
    _openingShop = true;
    try {
      final opened = await openRestaurantAtDish(
        context,
        ref,
        restaurantId: item.restaurantId,
        dishId: item.id,
      );
      if (!opened && mounted) {
        _showError(AppLocalizations.of(context)!.aiSearchShopUnavailable);
      }
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context)!.aiSearchErrorNetwork);
    } finally {
      _openingShop = false;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _searchExample(String query) {
    _queryController.text = query;
    _onSubmitText();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSearchProvider);
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          AiSearchAppBar(screenWidth: sw),
          SliverToBoxAdapter(
            child: AiSearchBar(
              controller: _queryController,
              focusNode: _focusNode,
              isLoading: state.isLoading,
              onSubmit: _onSubmitText,
              onCameraTap: _showImageSourceSheet,
            ),
          ),
          if (state.selectedImageFile != null && state.mode == AiSearchMode.image)
            SliverToBoxAdapter(
              child: AiImagePreview(
                imageFile: state.selectedImageFile!,
                onClose: () => ref.read(aiSearchProvider.notifier).reset(),
              ),
            ),

          // ── Body: one of loading / error / empty / no results / results ──
          if (state.isLoading)
            SliverToBoxAdapter(child: AiLoadingView(mode: state.mode))
          else if (state.hasError)
            SliverToBoxAdapter(
              child: AiErrorView(
                message: _errorText(AppLocalizations.of(context)!, state),
                icon: _errorIcon(state),
                onRetry: () => ref.read(aiSearchProvider.notifier).retry(),
              ),
            )
          else if (state.mode == AiSearchMode.none)
            SliverToBoxAdapter(
              child: AiEmptyState(
                screenWidth: sw,
                onExampleQuery: _searchExample,
                onPhotoTap: _showImageSourceSheet,
              ),
            )
          // Without the AI and with nothing found, "this dish is not
          // available" may be false: the search could not understand the
          // request. Say the smart search is unavailable instead.
          else if (!state.hasResults && state.isDegraded)
            SliverToBoxAdapter(
              child: AiErrorView(
                message: AppLocalizations.of(context)!.aiSearchErrorUnavailable,
                onRetry: () => ref.read(aiSearchProvider.notifier).retry(),
              ),
            )
          else if (!state.hasResults)
            SliverToBoxAdapter(child: AiNoResults(state: state))
          else
            _ResultsSection(state: state, onOpen: _openShop),
        ],
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// "These restaurants are closed" when every shop is, what the search
/// understood (intent chips, or the recognised dish), then one
/// AiSearchResultCard per result (the server puts open shops first); a tap
/// on one calls [onOpen].
class _ResultsSection extends StatelessWidget {
  const _ResultsSection({required this.state, required this.onOpen});

  final AiSearchState state;
  final ValueChanged<AiSearchFoodResult> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (state.isDegraded)
          const SliverToBoxAdapter(child: AiDegradedNote()),
        if (state.allShopsClosed)
          const SliverToBoxAdapter(child: AiAllClosedNotice()),
        if (state.mode == AiSearchMode.text && state.textResponse != null)
          SliverToBoxAdapter(
            child: AiIntentChips(response: state.textResponse!),
          ),
        if (state.mode == AiSearchMode.image && state.imageResponse != null)
          SliverToBoxAdapter(
            child: AiDishBadge(response: state.imageResponse!),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => AiSearchResultCard(
                item: state.results[i],
                onTap: () => onOpen(state.results[i]),
              ),
              childCount: state.results.length,
            ),
          ),
        ),
      ],
    );
  }
}
