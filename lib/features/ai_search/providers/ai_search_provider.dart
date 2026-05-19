import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_search_repository.dart';
import '../data/models/search_result.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final aiSearchRepositoryProvider = Provider<AiSearchRepository>(
  (ref) => AiSearchRepository(),
);

// ── State ─────────────────────────────────────────────────────────────────────

enum AiSearchMode { none, text, image }

class AiSearchState {
  final AiSearchMode mode;
  final bool isLoading;
  final String? errorMessage;

  /// The last conversational search response.
  final AiTextSearchResponse? textResponse;

  /// The last visual search response.
  final AiImageSearchResponse? imageResponse;

  /// The image file selected for visual search (shown as preview in the UI).
  final File? selectedImageFile;

  const AiSearchState({
    this.mode = AiSearchMode.none,
    this.isLoading = false,
    this.errorMessage,
    this.textResponse,
    this.imageResponse,
    this.selectedImageFile,
  });

  /// Combined results list regardless of mode.
  List<AiSearchFoodResult> get results {
    if (textResponse != null) return textResponse!.results;
    if (imageResponse != null) return imageResponse!.results;
    return const [];
  }

  bool get hasResults => results.isNotEmpty;

  AiSearchState copyWith({
    AiSearchMode? mode,
    bool? isLoading,
    String? errorMessage,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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

  /// Sends [query] (Darija / French / Arabic text) to the Edge Function
  /// and updates state with the structured results.
  Future<void> searchByText(String query) async {
    if (query.trim().isEmpty) return;

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
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
      );
    }
  }

  /// Sends [imageFile] to the Edge Function for visual dish recognition.
  Future<void> searchByImage(File imageFile) async {
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
      );
    }
  }

  /// Clears all results and resets to idle state.
  void reset() {
    state = const AiSearchState();
  }

  /// Clears only the error so the user can retry.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    if (msg.contains('Server misconfiguration')) {
      return 'Service temporarily unavailable. Try again later.';
    }
    if (msg.contains('No food dish detected')) {
      return 'Could not identify a dish in this photo. Try a clearer image.';
    }
    return msg.replaceFirst('Exception: ', '');
  }
}

// ── Public provider ───────────────────────────────────────────────────────────

final aiSearchProvider =
    StateNotifierProvider<AiSearchNotifier, AiSearchState>(
  (ref) => AiSearchNotifier(ref.watch(aiSearchRepositoryProvider)),
);
