import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/search_result.dart';

/// Repository that orchestrates calls to the `ai-search` Supabase Edge Function.
///
/// There are two entry points:
///   - [searchByText]  — Conversational / Darija text query.
///   - [searchByImage] — Visual search from a photo file.
class AiSearchRepository {
  AiSearchRepository();

  static const _functionName = 'ai-search';

  /// Performs a conversational text search.
  ///
  /// [query] — Any text in Darija, French, or Arabic.
  /// Throws on network / API errors.
  Future<AiTextSearchResponse> searchByText(String query) async {
    final supabase = Supabase.instance.client;

    final response = await supabase.functions.invoke(
      _functionName,
      body: {
        'mode': 'text',
        'query': query.trim(),
      },
    );

    _handleError(response);

    final data = response.data as Map<String, dynamic>;
    final intent = TextSearchIntent.fromJson(
      (data['intent'] as Map<String, dynamic>?) ?? {},
    );
    final rawResults = (data['results'] as List<dynamic>?) ?? [];
    final results = rawResults
        .map((r) => AiSearchFoodResult.fromJson(r as Map<String, dynamic>))
        .toList();

    return AiTextSearchResponse(intent: intent, results: results);
  }

  /// Performs a visual food search by sending an image file to the Edge Function.
  ///
  /// [imageFile] — The image picked from the gallery or camera.
  /// [mimeType]  — MIME type of the image (default: `image/jpeg`).
  Future<AiImageSearchResponse> searchByImage(
    File imageFile, {
    String mimeType = 'image/jpeg',
  }) async {
    final supabase = Supabase.instance.client;

    // Read and encode the image as base64
    final imageBytes = await imageFile.readAsBytes();
    final imageBase64 = base64Encode(imageBytes);

    // Sanity-check: Gemini 1.5 Flash supports up to 20MB inline data.
    // Warn if the image is unusually large.
    if (imageBytes.lengthInBytes > 10 * 1024 * 1024) {
      throw Exception(
        'Image is too large (${(imageBytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Please use an image smaller than 10 MB.',
      );
    }

    final response = await supabase.functions.invoke(
      _functionName,
      body: {
        'mode': 'image',
        'imageBase64': imageBase64,
        'mimeType': mimeType,
      },
    );

    _handleError(response);

    final data = response.data as Map<String, dynamic>;
    final rawResults = (data['results'] as List<dynamic>?) ?? [];
    final results = rawResults
        .map((r) => AiSearchFoodResult.fromJson(r as Map<String, dynamic>))
        .toList();

    return AiImageSearchResponse(
      dishName: data['dish_name'] as String?,
      confidence: (data['confidence'] as String?) ?? 'low',
      results: results,
    );
  }

  /// Throws a descriptive exception if the Edge Function returned an error.
  void _handleError(FunctionResponse response) {
    // supabase_flutter throws on HTTP errors, but sometimes wraps the error
    // inside the body with a 2xx status. Handle both cases.
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('error')) {
      final msg = data['error'] as String? ?? 'Unknown error';
      final details = data['details'] as String?;
      throw Exception('$msg${details != null ? '\n$details' : ''}');
    }
  }
}
