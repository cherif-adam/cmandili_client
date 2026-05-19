import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/search_result.dart';
import '../providers/ai_search_provider.dart';
import 'widgets/ai_search_result_card.dart';

/// Full-screen AI Search experience combining Darija text search
/// and visual search (order by photo) in a single, polished UI.
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
      _showError('Could not open image: $e');
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageSourceSheet(onSelect: (src) {
        Navigator.pop(ctx);
        _onPickImage(src);
      }),
    );
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSearchProvider);
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(sw),
          SliverToBoxAdapter(child: _buildSearchBar(sw, state)),
          if (state.selectedImageFile != null && state.mode == AiSearchMode.image)
            SliverToBoxAdapter(child: _buildImagePreview(state)),
          if (state.isLoading)
            SliverToBoxAdapter(child: _buildLoadingView(state.mode))
          else if (state.errorMessage != null)
            SliverToBoxAdapter(child: _buildErrorView(state.errorMessage!))
          else if (state.mode == AiSearchMode.none)
            SliverToBoxAdapter(child: _buildEmptyState(sw))
          else if (!state.hasResults)
            SliverToBoxAdapter(child: _buildNoResults(state))
          else ...[
            if (state.mode == AiSearchMode.text && state.textResponse != null)
              SliverToBoxAdapter(
                child: _buildIntentChips(state.textResponse!),
              ),
            if (state.mode == AiSearchMode.image && state.imageResponse != null)
              SliverToBoxAdapter(
                child: _buildDishBadge(state.imageResponse!),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => AiSearchResultCard(item: state.results[i]),
                  childCount: state.results.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(double sw) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppColors.textPrimary),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C3DE1), Color(0xFF8F57FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'AI Search',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: sw * 0.045,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      expandedHeight: 100,
    );
  }

  Widget _buildSearchBar(double sw, AiSearchState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C3DE1).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search_rounded,
                color: Color(0xFF6C3DE1), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _queryController,
                focusNode: _focusNode,
                onSubmitted: (_) => _onSubmitText(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'N7eb nekel 7aja 7arra… ou décris ce que tu veux',
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            // Camera / image button
            _AnimatedIconButton(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF6C3DE1),
              onTap: _showImageSourceSheet,
              tooltip: 'Search by photo',
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: state.isLoading ? null : _onSubmitText,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: state.isLoading
                      ? const LinearGradient(
                          colors: [Colors.grey, Colors.grey])
                      : const LinearGradient(
                          colors: [Color(0xFF6C3DE1), Color(0xFF8F57FB)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(AiSearchState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              state.selectedImageFile!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay with label
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C3DE1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_search_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Visual Search',
                      style:
                          TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => ref.read(aiSearchProvider.notifier).reset(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentChips(AiTextSearchResponse response) {
    final intent = response.intent;
    final chips = <String>[];
    if (intent.category != null && intent.category != 'general') {
      chips.add('🍽 ${intent.category}');
    }
    if (intent.keyword != null) chips.add('🔍 ${intent.keyword}');
    if (intent.spicy == true) chips.add('🌶 Spicy');
    if (intent.vegetarian == true) chips.add('🥦 Vegetarian');
    if (intent.maxPrice != null) {
      chips.add('≤ ${intent.maxPrice!.toStringAsFixed(0)} DT');
    }
    if (intent.deliveryTime == 'fast') chips.add('⚡ Fast');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Color(0xFF6C3DE1)),
              const SizedBox(width: 6),
              Text(
                '${response.results.length} result${response.results.length != 1 ? 's' : ''} found',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: chips
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C3DE1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C3DE1),
                              fontWeight: FontWeight.w500)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDishBadge(AiImageSearchResponse response) {
    if (response.dishName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded,
              size: 16, color: Color(0xFF6C3DE1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Identified: "${response.dishName}" · ${response.results.length} restaurant${response.results.length != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _ConfidenceBadge(confidence: response.confidence),
        ],
      ),
    );
  }

  Widget _buildLoadingView(AiSearchMode mode) {
    final label = mode == AiSearchMode.image
        ? 'Analyzing your photo…'
        : 'Understanding your request…';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AiSpinner(),
          const SizedBox(height: 20),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Powered by AI',
              style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          ),
          const SizedBox(height: 16),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref.read(aiSearchProvider.notifier).clearError(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C3DE1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double sw) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.1, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3DE1), Color(0xFF8F57FB)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3DE1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Describe what you want',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Type in Darija, French or Arabic — or upload a photo of a dish you want to find.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          // Example queries
          _ExampleQuery(
            emoji: '🌶',
            text: '"N7eb nekel 7aja 7arra w ma tfoutch 15 dinar"',
            onTap: () {
              _queryController.text =
                  'N7eb nekel 7aja 7arra w ma tfoutch 15 dinar';
              _onSubmitText();
            },
          ),
          const SizedBox(height: 10),
          _ExampleQuery(
            emoji: '⚡',
            text: '"Quelque chose de rapide, pizza ou burger"',
            onTap: () {
              _queryController.text = 'Quelque chose de rapide, pizza ou burger';
              _onSubmitText();
            },
          ),
          const SizedBox(height: 10),
          _ExampleQuery(
            emoji: '📸',
            text: 'Upload a food photo',
            onTap: _showImageSourceSheet,
            isImageOption: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(AiSearchState state) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            state.mode == AiSearchMode.image
                ? 'No restaurants found for "${state.imageResponse?.dishName ?? 'this dish'}"'
                : 'No dishes match your request',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _AnimatedIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final void Function(ImageSource) onSelect;
  const _ImageSourceSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Search by Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a photo of a dish to find it in Kairouan',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => onSelect(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => onSelect(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C3DE1).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF6C3DE1).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C3DE1), size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C3DE1))),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'high' => AppColors.success,
      'medium' => AppColors.warning,
      _ => AppColors.textLight,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confidence.toUpperCase(),
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AiSpinner extends StatelessWidget {
  const _AiSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF6C3DE1)),
          ),
          const Icon(Icons.auto_awesome_rounded,
              color: Color(0xFF6C3DE1), size: 20),
        ],
      ),
    );
  }
}

class _ExampleQuery extends StatelessWidget {
  final String emoji;
  final String text;
  final VoidCallback onTap;
  final bool isImageOption;

  const _ExampleQuery({
    required this.emoji,
    required this.text,
    required this.onTap,
    this.isImageOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isImageOption
                ? const Color(0xFF6C3DE1).withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isImageOption
                      ? const Color(0xFF6C3DE1)
                      : AppColors.textSecondary,
                  fontStyle: isImageOption
                      ? FontStyle.normal
                      : FontStyle.italic,
                  fontWeight:
                      isImageOption ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              isImageOption
                  ? Icons.camera_alt_rounded
                  : Icons.north_west_rounded,
              size: 16,
              color: const Color(0xFF6C3DE1).withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
