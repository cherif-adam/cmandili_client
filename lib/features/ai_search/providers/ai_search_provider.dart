import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_search_repository.dart';
import '../data/models/search_result.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final aiSearchRepositoryProvider = Provider<AiSearchRepository>(
  (ref) => AiSearchRepository(),
);

// ── State ─────────────────────────────────────────────────────────────────────

enum AiSearchMode { none, text, image }

/// What went wrong, so the screen can say it in the customer's language.
/// There is deliberately no kind carrying the server's own text: the screen
/// once printed `FunctionException.toString()`, Gemini's error JSON included.
enum AiSearchErrorKind { network, unavailable, imageTooLarge }

class AiSearchState {
  final AiSearchMode mode;
  final bool isLoading;

  /// Set when the search failed (no answer at all, as opposed to an answer
  /// with no results).
  final AiSearchErrorKind? errorKind;

  /// Only for [AiSearchErrorKind.imageTooLarge]: the size in MB.
  final String? errorDetail;

  /// The last conversational search response.
  final AiTextSearchResponse? textResponse;

  /// The last visual search response.
  final AiImageSearchResponse? imageResponse;

  /// The image file selected for visual search (shown as preview in the UI).
  final File? selectedImageFile;

  const AiSearchState({
    this.mode = AiSearchMode.none,
    this.isLoading = false,
    this.errorKind,
    this.errorDetail,
    this.textResponse,
    this.imageResponse,
    this.selectedImageFile,
  });

  bool get hasError => errorKind != null;

  /// Combined results list regardless of mode.
  List<AiSearchFoodResult> get results {
    if (textResponse != null) return textResponse!.results;
    if (imageResponse != null) return imageResponse!.results;
    return const [];
  }

  bool get hasResults => results.isNotEmpty;

  /// The function's verdict on the last answer, null before any answer.
  AiSearchStatus? get status => textResponse?.status ?? imageResponse?.status;

  /// The answer came from the search without AI.
  bool get isDegraded => status == AiSearchStatus.degraded;

  /// A photo in which no dish was recognised.
  bool get noDishInPhoto => imageResponse?.noDishDetected ?? false;

  /// Every result comes from a closed shop. They are listed anyway, dimmed
  /// like closed shops on the home screen, and the screen says why above them.
  bool get allShopsClosed =>
      hasResults && results.every((r) => !r.restaurantIsOpen);

  AiSearchState copyWith({
    AiSearchMode? mode,
    bool? isLoading,
    AiSearchErrorKind? errorKind,
    String? errorDetail,
    AiTextSearchResponse? textResponse,
    AiImageSearchResponse? imageResponse,
    File? selectedImageFile,
    bool clearError = false,
    bool clearImage = false,
    bool clearTextResponse = false,
    bool clearImageResponse = false,
  }) {
    return AiSearchState(
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      textResponse: clearTextResponse ? null : (textResponse ?? this.textResponse),
      imageResponse: clearImageResponse ? null : (imageResponse ?? this.imageResponse),
      selectedImageFile: clearImage ? null : (selectedImageFile ?? this.selectedImageFile),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AiSearchNotifier extends StateNotifier<AiSearchState> {
  final AiSearchRepository _repository;

  AiSearchNotifier(this._repository) : super(const AiSearchState());

  /// The last search, so "Réessayer" runs it again.
  String? _lastQuery;
  File? _lastImage;

  /// Sends [query] (Darija / French / Arabic text) to the Edge Function
  /// and updates state with the structured results.
  Future<void> searchByText(String query) async {
    if (query.trim().isEmpty) return;
    _lastQuery = query;
    _lastImage = null;

    state = AiSearchState(
      mode: AiSearchMode.text,
      isLoading: true,
      // Preserve image file in case user switches back
      selectedImageFile: state.selectedImageFile,
    );

    try {
      final response = await _repository.searchByText(query);
      state = state.copyWith(
        isLoading: false,
        textResponse: response,
        clearError: true,
        clearImageResponse: true,
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// Sends [imageFile] to the Edge Function for visual dish recognition.
  Future<void> searchByImage(File imageFile) async {
    _lastImage = imageFile;
    _lastQuery = null;

    state = AiSearchState(
      mode: AiSearchMode.image,
      isLoading: true,
      selectedImageFile: imageFile,
    );

    try {
      final response = await _repository.searchByImage(imageFile);
      state = state.copyWith(
        isLoading: false,
        imageResponse: response,
        clearError: true,
        clearTextResponse: true,
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// Runs the last search again ("Réessayer").
  Future<void> retry() async {
    final query = _lastQuery;
    final image = _lastImage;
    if (state.mode == AiSearchMode.image && image != null) {
      await searchByImage(image);
    } else if (query != null) {
      await searchByText(query);
    } else {
      clearError();
    }
  }

  /// Clears all results and resets to idle state.
  void reset() {
    _lastQuery = null;
    _lastImage = null;
    state = const AiSearchState();
  }

  /// Clears only the error so the user can retry.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _fail(Object e) {
    // Logged for debugging, never shown: the screen words each kind itself.
    debugPrint('AiSearchNotifier: $e');
    state = state.copyWith(
      isLoading: false,
      errorKind: classifyError(e),
      errorDetail: e is AiImageTooLargeException
          ? e.megabytes.toStringAsFixed(1)
          : null,
    );
  }

  /// Anything that is not a too-large photo or a lost connection is "the
  /// smart search is unavailable" — including a FunctionException, a timeout
  /// or a payload we cannot read.
  @visibleForTesting
  static AiSearchErrorKind classifyError(Object e) {
    if (e is AiImageTooLargeException) return AiSearchErrorKind.imageTooLarge;
    if (e is AiSearchNetworkException || e is SocketException) {
      return AiSearchErrorKind.network;
    }
    return AiSearchErrorKind.unavailable;
  }
}

// ── Public provider ───────────────────────────────────────────────────────────

final aiSearchProvider =
    StateNotifierProvider<AiSearchNotifier, AiSearchState>(
  (ref) => AiSearchNotifier(ref.watch(aiSearchRepositoryProvider)),
);
