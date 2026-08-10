/// The learner's level — the tutor adapts its language and depth to this.
enum TutorLevel { beginner, intermediate, advanced, caFinal }

TutorLevel tutorLevelFromIndex(int levelIndex) => switch (levelIndex) {
      1 => TutorLevel.beginner,
      2 => TutorLevel.intermediate,
      3 => TutorLevel.advanced,
      _ => TutorLevel.caFinal,
    };

String tutorLevelLabel(TutorLevel level) => switch (level) {
      TutorLevel.beginner => 'Beginner',
      TutorLevel.intermediate => 'Intermediate',
      TutorLevel.advanced => 'Advanced',
      TutorLevel.caFinal => 'CA Final',
    };

/// A message in the tutor conversation.
class TutorMessage {
  const TutorMessage({
    required this.role,
    required this.text,
    this.isHint = false,
  });

  final String role; // 'user' | 'assistant'
  final String text;

  /// Hint-mode messages coach through reasoning rather than giving answers.
  final bool isHint;

  Map<String, dynamic> toJson() =>
      {'role': role, 'text': text, 'isHint': isHint};
}

/// Context the tutor can use to ground its answer.
class TutorContext {
  const TutorContext({
    this.question,
    this.lessonTitle,
    this.lessonSummary,
    this.lessonSections = const [],
    this.skill,
  });

  final String? question;
  final String? lessonTitle;
  final String? lessonSummary;
  final List<String> lessonSections;
  final String? skill;
}

/// Abstraction over AI providers. The concrete provider (OpenAI, Gemini,
/// local LLM, or the built-in coach) is selected at wiring time — features
/// only ever depend on this interface.
///
/// Security rule: provider API keys never live in client code; the remote
/// implementation must proxy through a server endpoint you control.
abstract interface class AiTutorService {
  Future<String> ask({
    required String prompt,
    required TutorLevel level,
    TutorContext? context,
    List<TutorMessage> history = const [],
  });

  /// When true, the service prefers Socratic hints over direct answers.
  bool get prefersHints;
}
