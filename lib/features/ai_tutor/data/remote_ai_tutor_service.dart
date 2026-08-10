import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/ai_tutor_service.dart';

/// Remote AI tutor.
///
/// Security: the client never holds the provider key. [AppConfig.aiEndpoint]
/// must point at YOUR server, which holds the provider credential and relays
/// the request (server-side rate limiting, prompt filtering, audit logging).
class RemoteAiTutorService implements AiTutorService {
  RemoteAiTutorService({
    required this.endpoint,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final String apiKey;
  final http.Client _client;

  @override
  bool get prefersHints => false;

  @override
  Future<String> ask({
    required String prompt,
    required TutorLevel level,
    TutorContext? context,
    List<TutorMessage> history = const [],
  }) async {
    final uri = Uri.parse(endpoint);
    final body = jsonEncode({
      'prompt': prompt,
      'level': level.name,
      'context': {
        if (context?.question != null) 'question': context!.question,
        if (context?.lessonTitle != null) 'lessonTitle': context!.lessonTitle,
        if (context?.lessonSummary != null) 'lessonSummary': context!.lessonSummary,
        if (context != null) 'sections': context.lessonSections,
        if (context?.skill != null) 'skill': context!.skill,
      },
      'history': history.map((m) => m.toJson()).toList(),
      'preferHints': true,
    });
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw RemoteServiceException(
          'The tutor could not answer right now (${response.statusCode}).',
          code: 'ai_http_${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final answer = json['answer'] as String? ?? json['text'] as String?;
      if (answer == null || answer.trim().isEmpty) {
        throw const RemoteServiceException(
          'The tutor returned an empty response.',
          code: 'ai_empty',
        );
      }
      return answer;
    } on RemoteServiceException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Could not reach the tutor. Check your connection and try again.',
        code: 'ai_network',
        cause: e,
      );
    }
  }
}
