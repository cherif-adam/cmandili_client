import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/search_result.dart';

/// The photo is over the 10 MB the visual search accepts.
class AiImageTooLargeException implements Exception {
  const AiImageTooLargeException(this.megabytes);

  final double megabytes;

  @override
  String toString() =>
      'AiImageTooLargeException(${megabytes.toStringAsFixed(1)} MB)';
}

/// The phone could not reach the server (no signal, DNS, socket reset).
class AiSearchNetworkException implements Exception {
  const AiSearchNetworkException();

  @override
  String toString() => 'AiSearchNetworkException';
}

/// The search could not answer: the function failed (5xx), timed out, or
/// answered with an error. Carries NO server text on purpose — the screen
/// used to print `FunctionException.toString()`, Gemini's 429 JSON included.
/// The cause is logged with debugPrint here and on the server.
class AiSearchUnavailableException implements Exception {
  const AiSearchUnavailableException();

  @override
  String toString() => 'AiSearchUnavailableException';
}

/// Repository that orchestrates calls to the `ai-search` Supabase Edge Function.
///
/// There are two entry points:
///   - [searchByText]  — Conversational / Darija text query.
///   - [searchByImage] — Visual search from a photo file.
///
/// Every failure becomes one of the three exceptions above; nothing else
/// escapes, so nothing raw can reach the screen.
class AiSearchRepository {
  AiSearchRepository();

  static const _functionName = 'ai-search';

  /// Longer than the function's own worst case (two providers, then the
  /// database), shorter than a customer's patience.
  static const _timeout = Duration(seconds: 60);

  /// Performs a conversational text search.
  ///
  /// [query] — Any text in Darija, French, or Arabic.
  Future<AiTextSearchResponse> searchByText(String query) async {
    final data = await _invoke({
      'mode': 'text',
      'query': query.trim(),
    });

    final intent = TextSearchIntent.fromJson(
      (data['intent'] as Map<String, dynamic>?) ?? {},
    );
    final results = _results(data);

    return AiTextSearchResponse(
      intent: intent,
      results: results,
      isFallback: (data['fallback'] as bool?) ?? false,
      status: AiSearchStatus.parse(data['status'],
          hasResults: results.isNotEmpty),
    );
  }

  /// Performs a visual food search by sending an image file to the Edge Function.
  ///
  /// [imageFile] — The image picked from the gallery or camera.
  /// [mimeType]  — MIME type of the image (default: `image/jpeg`).
  Future<AiImageSearchResponse> searchByImage(
    File imageFile, {
    String mimeType = 'image/jpeg',
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    if (imageBytes.lengthInBytes > 10 * 1024 * 1024) {
      throw AiImageTooLargeException(imageBytes.lengthInBytes / 1024 / 1024);
    }

    final data = await _invoke({
      'mode': 'image',
      'imageBase64': base64Encode(imageBytes),
      'mimeType': mimeType,
    });
    final results = _results(data);

    return AiImageSearchResponse(
      dishName: data['dish_name'] as String?,
      confidence: (data['confidence'] as String?) ?? 'low',
      results: results,
      status: AiSearchStatus.parse(data['status'],
          hasResults: results.isNotEmpty),
      noDishDetected: data['reason'] == 'no_dish',
    );
  }

  static List<AiSearchFoodResult> _results(Map<String, dynamic> data) => [
        for (final r in (data['results'] as List<dynamic>?) ?? const [])
          if (r is Map<String, dynamic>) AiSearchFoodResult.fromJson(r),
      ];

  /// Calls the function and returns its JSON body, or throws one of the
  /// exceptions above.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions
          .invoke(_functionName, body: body)
          .timeout(_timeout);
    } on FunctionException catch (e) {
      debugPrint('ai-search: HTTP ${e.status}');
      throw const AiSearchUnavailableException();
    } on SocketException catch (e) {
      debugPrint('ai-search: $e');
      throw const AiSearchNetworkException();
    } on http.ClientException catch (e) {
      debugPrint('ai-search: $e');
      throw const AiSearchNetworkException();
    } on TimeoutException {
      debugPrint('ai-search: no answer after ${_timeout.inSeconds}s');
      throw const AiSearchUnavailableException();
    } catch (e) {
      debugPrint('ai-search: $e');
      throw const AiSearchUnavailableException();
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      debugPrint('ai-search: unexpected payload ${data.runtimeType}');
      throw const AiSearchUnavailableException();
    }
    if (data['error'] != null) {
      debugPrint('ai-search: ${data['code'] ?? 'error'}');
      throw const AiSearchUnavailableException();
    }
    return data;
  }
}
