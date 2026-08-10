import 'package:decimal/decimal.dart';

import '../../core/utils/money.dart';
import '../../domain/accounting/account.dart';
import '../../domain/accounting/journal.dart';
import '../../domain/accounting/simulator_engine.dart';
import 'difficulty.dart';

enum QuestionType {
  mcq,
  numerical,
  journalEntry,
  fillBlank,
  trueFalse,
  errorCorrection,
  matchItems,
  financialStatement,
  caseStudy,
  multiStep;

  static QuestionType fromString(String value) => switch (value) {
        'mcq' => mcq,
        'numerical' => numerical,
        'journal_entry' => journalEntry,
        'fill_blank' => fillBlank,
        'true_false' => trueFalse,
        'error_correction' => errorCorrection,
        'match_items' => matchItems,
        'financial_statement' => financialStatement,
        'case_study' => caseStudy,
        'multi_step' => multiStep,
        _ => mcq,
      };

  String get label => switch (this) {
        mcq => 'Multiple choice',
        numerical => 'Numerical answer',
        journalEntry => 'Journal entry',
        fillBlank => 'Fill in the blank',
        trueFalse => 'True / False',
        errorCorrection => 'Error correction',
        matchItems => 'Match items',
        financialStatement => 'Financial statement',
        caseStudy => 'Case study',
        multiStep => 'Multi-step problem',
      };
}

class QuestionOption {
  const QuestionOption({required this.key, required this.text});

  final String key;
  final String text;

  factory QuestionOption.fromJson(Map<String, dynamic> json) =>
      QuestionOption(key: json['key'] as String, text: json['text'] as String);

  Map<String, dynamic> toJson() => {'key': key, 'text': text};
}

/// Structured correct-answer data for a question.
class AnswerData {
  const AnswerData({
    this.keys = const [],
    this.value,
    this.accepted = const [],
    this.journalLines = const [],
  });

  /// Option keys for MCQ / true-false.
  final List<String> keys;

  /// Exact numeric value for numerical questions.
  final String? value;

  /// Accepted textual variants (fill-blank, comma-formatted numbers).
  final List<String> accepted;

  /// Expected journal lines for journal-entry questions:
  /// (accountName, side, amount-as-string).
  final List<({String account, String side, String amount})> journalLines;

  factory AnswerData.fromJson(Map<String, dynamic> json) {
    final journalRaw = json['journal'] as List<dynamic>? ?? const [];
    return AnswerData(
      keys: (json['keys'] as List<dynamic>? ?? const []).cast<String>(),
      value: json['value'] as String?,
      accepted: (json['accepted'] as List<dynamic>? ?? const []).cast<String>(),
      journalLines: journalRaw
          .map((e) => (
                account: (e as Map<String, dynamic>)['account'] as String,
                side: e['side'] as String,
                amount: e['amount'] as String,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (keys.isNotEmpty) 'keys': keys,
        if (value != null) 'value': value,
        if (accepted.isNotEmpty) 'accepted': accepted,
        if (journalLines.isNotEmpty)
          'journal': journalLines
              .map((l) => {'account': l.account, 'side': l.side, 'amount': l.amount})
              .toList(),
      };
}

class QuestionData {
  const QuestionData({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.stem,
    required this.answer,
    required this.explanation,
    required this.options,
    this.whyOthersWrong = const [],
    this.commonMistake,
    this.hint,
    this.tags = const [],
    this.skills = const [],
    this.marks = 1,
    this.negativeMarks = 0,
    this.estimatedSeconds = 60,
  });

  final String id;
  final QuestionType type;
  final Difficulty difficulty;
  final String stem;
  final AnswerData answer;
  final String explanation;
  final List<QuestionOption> options;
  final List<({String key, String why})> whyOthersWrong;
  final String? commonMistake;
  final String? hint;
  final List<String> tags;
  final List<String> skills;
  final num marks;
  final num negativeMarks;
  final int estimatedSeconds;

  factory QuestionData.fromJson(Map<String, dynamic> json) => QuestionData(
        id: json['id'] as String,
        type: QuestionType.fromString(json['type'] as String? ?? 'mcq'),
        difficulty: Difficulty.fromString(json['difficulty'] as String? ?? 'easy'),
        stem: json['stem'] as String,
        answer: AnswerData.fromJson(
            (json['answer'] as Map<String, dynamic>?) ?? const {}),
        explanation: json['explanation'] as String? ?? '',
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        whyOthersWrong: (json['whyOthersWrong'] as List<dynamic>? ?? const [])
            .map((e) => (
                  key: (e as Map<String, dynamic>)['key'] as String,
                  why: e['why'] as String,
                ))
            .toList(),
        commonMistake: json['commonMistake'] as String?,
        hint: json['hint'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
        skills: (json['skills'] as List<dynamic>? ?? const []).cast<String>(),
        marks: json['marks'] as num? ?? 1,
        negativeMarks: json['negativeMarks'] as num? ?? 0,
        estimatedSeconds: json['estimatedSeconds'] as int? ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'difficulty': difficulty.name,
        'stem': stem,
        'answer': answer.toJson(),
        'explanation': explanation,
        'options': options.map((o) => o.toJson()).toList(),
        'whyOthersWrong': whyOthersWrong
            .map((e) => {'key': e.key, 'why': e.why})
            .toList(),
        if (commonMistake != null) 'commonMistake': commonMistake,
        if (hint != null) 'hint': hint,
        'tags': tags,
        'skills': skills,
        'marks': marks,
        'negativeMarks': negativeMarks,
        'estimatedSeconds': estimatedSeconds,
      };
}

/// What the user submitted for a question.
class UserAnswer {
  const UserAnswer({
    this.selectedKeys = const [],
    this.text,
    this.journal,
  });

  final List<String> selectedKeys;
  final String? text;

  /// Structured journal entry for journal-entry questions.
  final JournalEntry? journal;

  bool get isEmpty =>
      selectedKeys.isEmpty && (text == null || text!.trim().isEmpty) && journal == null;

  Map<String, dynamic> toJson() => {
        if (selectedKeys.isNotEmpty) 'keys': selectedKeys,
        if (text != null) 'text': text,
        if (journal != null)
          'journal': journal!.lines
              .map((l) => {
                    'account': l.account.name,
                    'side': l.isDebit ? 'debit' : 'credit',
                    'amount': l.amount.toString(),
                  })
              .toList(),
      };
}

/// Result of checking an answer against a question.
class AnswerCheckResult {
  const AnswerCheckResult({
    required this.isCorrect,
    required this.userAnswer,
    this.partial = false,
  });

  final bool isCorrect;
  final bool partial;
  final UserAnswer userAnswer;
}

/// Checks a user answer against the question's expected answer.
///
/// Numeric answers are compared as exact decimals (commas and currency
/// symbols are tolerated — see [tryParseAmount]).
AnswerCheckResult checkAnswer(QuestionData question, UserAnswer answer) {
  if (question.type == QuestionType.journalEntry) {
    return _checkJournal(question, answer);
  }

  switch (question.type) {
    case QuestionType.mcq:
    case QuestionType.trueFalse:
      final expected = question.answer.keys.toSet();
      final given = answer.selectedKeys.toSet();
      return AnswerCheckResult(
        isCorrect: expected.isNotEmpty && expected.length == given.length && expected.containsAll(given),
        userAnswer: answer,
      );
    case QuestionType.numerical:
      final text = answer.text?.trim() ?? '';
      final given = tryParseAmount(text);
      if (given == null) {
        return AnswerCheckResult(isCorrect: false, userAnswer: answer);
      }
      final accepted = [
        if (question.answer.value != null) tryParseAmount(question.answer.value!),
        ...question.answer.accepted.map(tryParseAmount),
      ].whereType<Decimal>();
      return AnswerCheckResult(
        isCorrect: accepted.any((a) => a == given),
        userAnswer: answer,
      );
    case QuestionType.fillBlank:
      final text = answer.text?.trim().toLowerCase() ?? '';
      final accepted =
          question.answer.accepted.map((a) => a.trim().toLowerCase()).toSet();
      return AnswerCheckResult(
        isCorrect: accepted.contains(text),
        userAnswer: answer,
      );
    default:
      // Unsupported interactive type — check like MCQ when options carry keys.
      final expected = question.answer.keys.toSet();
      final given = answer.selectedKeys.toSet();
      return AnswerCheckResult(
        isCorrect: expected.isNotEmpty && expected.containsAll(given) && expected.length == given.length,
        userAnswer: answer,
      );
  }
}

AnswerCheckResult _checkJournal(QuestionData question, UserAnswer answer) {
  final userJournal = answer.journal;
  if (userJournal == null) {
    return AnswerCheckResult(isCorrect: false, userAnswer: answer);
  }

  final expectedLines = <({Account account, JournalSide side, Decimal amount})>[];
  for (final line in question.answer.journalLines) {
    final account = ChartOfAccounts.byName(line.account) ??
        Account(line.account, AccountCategory.asset);
    expectedLines.add((
      account: account,
      side: line.side == 'credit' ? JournalSide.credit : JournalSide.debit,
      amount: tryParseAmount(line.amount) ?? Decimal.zero,
    ));
  }

  // Build the same check used by the simulator engine.
  final spec = SimulatorTransactionSpec(
    seq: 0,
    narration: question.stem,
    expectedLines: [
      for (final l in expectedLines)
        ExpectedJournalLine(accountName: l.account.name, side: l.side, amount: l.amount),
    ],
  );

  return AnswerCheckResult(
    isCorrect: checkSimulatorJournal(userJournal, spec).isCorrect,
    userAnswer: answer,
  );
}
