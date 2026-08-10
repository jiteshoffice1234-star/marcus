import '../domain/ai_tutor_service.dart';

/// The built-in accounting coach.
///
/// This is a real, deterministic tutor that works fully offline: it grounds
/// answers in the current lesson context, applies the rules of accounting, and
/// adapts language to the learner's level. It deliberately teaches through
/// hints and reasoning rather than dumping answers. A remote LLM provider can
/// be swapped in behind [AiTutorService] without touching the UI.
class CoachAiTutorService implements AiTutorService {
  CoachAiTutorService();

  @override
  bool get prefersHints => true;

  @override
  Future<String> ask({
    required String prompt,
    required TutorLevel level,
    TutorContext? context,
    List<TutorMessage> history = const [],
  }) async {
    final lowered = prompt.toLowerCase();
    final topic = _detectTopic(lowered, context);

    // 1. Journal-entry checking — real engine-backed validation.
    if (topic == 'journal' && (lowered.contains('check') || lowered.contains('correct') || lowered.contains('entry'))) {
      return _journalGuidance(level);
    }

    // 2. "Harder question" — escalate difficulty.
    if (lowered.contains('harder') || lowered.contains('difficult question')) {
      return _harderQuestion(level);
    }

    // 3. Grounded concept explanations.
    for (final section in context?.lessonSections ?? const <String>[]) {
      if (lowered.contains('explain') || lowered.contains('what is') || lowered.contains('simply')) {
        if (section.toLowerCase().contains(topic) || topic.isEmpty) {
          return _adapt(section, level);
        }
      }
    }

    // 4. Rules lookup.
    final rule = _rules[topic];
    if (rule != null) {
      return _adapt(rule, level);
    }

    // 5. Fallback: coach with the lesson summary + a guiding question.
    if (context?.lessonTitle != null) {
      return _adapt(
        'We are studying "${context!.lessonTitle}". ${context.lessonSummary ?? ''} '
        'Try restating the problem in your own words, then ask yourself: which '
        'accounts are affected, and on which side do they increase?',
        level,
      );
    }

    return _adapt(
      'Here is how to approach any accounting question: 1) identify the accounts '
      'involved, 2) decide each account\'s type (asset, liability, capital, income, '
      'expense), 3) apply the rule — assets and expenses increase on the debit side, '
      'the rest on the credit side, 4) check that debits equal credits. Try that '
      'reasoning on the question, and tell me what you got.',
      level,
    );
  }

  String _adapt(String text, TutorLevel level) {
    if (level == TutorLevel.beginner) return text;
    if (level == TutorLevel.intermediate) {
      return '$text\n\n(Intermediate note: as you advance, watch for how the '
          'matching and prudence concepts apply to this situation.)';
    }
    if (level == TutorLevel.advanced) {
      return '$text\n\n(Advanced note: consider the impact on financial statement '
          'presentation and disclosures, and how this maps under Ind AS/IFRS '
          'principles.)';
    }
    return '$text\n\n(CA Final note: analyse this at the level of recognition, '
        'measurement and disclosure requirements — including consolidation '
        'implications where relevant — and cite the applicable standard.)';
  }

  String _journalGuidance(TutorLevel level) {
    final base = 'To check a journal entry: verify each account is classified '
        'correctly (asset/liability/capital/income/expense), confirm the side '
        '(assets & expenses debit; liabilities, capital & income credit), and '
        'ensure total debits equal total credits. If the balance sheet does not '
        'match, re-trace the entries that touch cash and bank first — that is '
        'where imbalance most often creeps in.';
    return _adapt(base, level);
  }

  String _harderQuestion(TutorLevel level) {
    return switch (level) {
      TutorLevel.beginner =>
        'Try this: a business buys furniture for ₹50,000 on credit from a supplier '
            'and pays ₹10,000 cash as a partial settlement the same day. Write both '
            'journal entries, then say what each account\'s balance looks like. '
            'Reason step by step before checking.',
      TutorLevel.intermediate =>
        'Try this: goods costing ₹80,000 are sold for ₹1,20,000 on credit. The '
            'customer later returns goods with a selling price of ₹12,000. Record '
            'the sale, the cost of goods sold, and the sales return, then compute '
            'gross profit.',
      TutorLevel.advanced =>
        'Try this: a parent sells inventory to its subsidiary at cost plus 25%. '
            'At year end 40% of that inventory remains unsold. Compute the '
            'unrealised profit to eliminate in consolidation, and state the '
            'adjusting entries.',
      TutorLevel.caFinal =>
        'Try this: in consolidation, a subsidiary reports a net loss while its '
            'non-controlling interest has a deficit balance. How is the NCI '
            'deficit presented, and what are the journal adjustments in the '
            'consolidated financial statements?',
    };
  }

  String _detectTopic(String lowered, TutorContext? context) {
    const map = {
      'debit': 'debit_credit',
      'credit': 'debit_credit',
      'journal': 'journal',
      'entry': 'journal',
      'ledger': 'ledger',
      'trial balance': 'trial_balance',
      'depreciat': 'depreciation',
      'gst': 'gst',
      'tds': 'tds',
      'accrual': 'accruals',
      'prepay': 'accruals',
      'provision': 'provisions',
      'bad debt': 'bad_debts',
      'inventory': 'inventory',
      'stock': 'inventory',
      'cash flow': 'cash_flow',
      'balance sheet': 'balance_sheet',
      'profit': 'profit_loss',
      'consolidat': 'consolidation',
      'ind as': 'ind_as',
      'accounting standard': 'standards',
      'partnership': 'partnership',
      'branch': 'branch',
      'equation': 'equation',
      'asset': 'assets',
      'liabilit': 'liabilities',
      'capital': 'capital',
    };
    for (final entry in map.entries) {
      if (lowered.contains(entry.key)) return entry.value;
    }
    if (context?.skill != null) return context!.skill!;
    return '';
  }

  /// Concise, level-agnostic rules (the coach adapts them per level).
  static const Map<String, String> _rules = {
    'debit_credit':
        'Rule of debit and credit: assets and expenses increase on the debit '
            'side and decrease on the credit side. Liabilities, capital and income '
            'increase on the credit side and decrease on the debit side. Every '
            'transaction has equal debits and credits.',
    'journal':
        'A journal entry records a transaction in the book of original entry: '
            'debit the account(s) first, credit the account(s) below (indented), '
            'and add a narration. Total debits must equal total credits.',
    'ledger':
        'The ledger is the principal book of accounts. Every journal entry is '
            'posted to individual accounts. An account balances on the side with '
            'the larger total.',
    'trial_balance':
        'A trial balance lists every ledger account balance, debits in one column '
            'and credits in another. Equal totals prove the arithmetic of posting '
            'but cannot catch errors that keep debits and credits equal.',
    'equation':
        'The accounting equation: Assets = Liabilities + Capital. It must hold '
            'after every transaction.',
    'depreciation':
        'Depreciation spreads an asset\'s cost over its useful life. Straight '
            'line: (Cost − Residual Value) ÷ Useful Life. Reducing balance applies '
            'a fixed percentage to the written-down value each year.',
    'accruals':
        'Accruals and prepayments match costs to the period they belong to: '
            'outstanding expenses are added to the P&L expense and shown as a '
            'liability; prepayments are deducted and shown as an asset.',
    'provisions':
        'A provision recognises an estimated liability (e.g. doubtful debts) '
            'under prudence — record the expected loss now, not when it becomes '
            'certain.',
    'bad_debts':
        'Bad debts are written off by debiting Bad Debts (expense) and crediting '
            'the customer\'s account. The provision for doubtful debts covers '
            'estimated future failures on the remaining receivables.',
    'gst':
        'GST: collect output GST on sales and claim input GST on purchases; '
            'remit the net difference. Sales are recorded net of GST; input GST is '
            'a receivable until set off.',
    'tds':
        'TDS: deduct tax at source on specified payments, record it as a payable '
            '(not an expense), deposit it with the government, and the payee '
            'claims it as credit.',
    'inventory':
        'Inventory is valued at the lower of cost and net realisable value. FIFO '
            'assumes oldest stock is sold first; weighted average smooths cost '
            'fluctuations.',
    'cash_flow':
        'The cash flow statement splits cash into operating, investing and '
            'financing activities. Under the indirect method start with net '
            'profit, add back non-cash items, and adjust for working capital '
            'changes.',
    'balance_sheet':
        'The balance sheet is a snapshot: Assets on one side, Liabilities and '
            'Capital on the other. Net profit increases capital; drawings and '
            'losses reduce it.',
    'profit_loss':
        'The P&L shows performance over a period: gross profit from trading '
            '(Sales − Cost of Goods Sold), then net profit after indirect expenses '
            'and other income.',
    'consolidation':
        'Consolidation combines a parent and its subsidiaries into one set of '
            'financial statements: eliminate the investment against subsidiary '
            'equity, remove intra-group balances and transactions, and recognise '
            'non-controlling interests.',
    'ind_as':
        'Ind AS (Indian Accounting Standards) converge with IFRS. Key themes: '
            'fair-value measurement where required, substance over form, and '
            'comprehensive disclosure.',
    'standards':
        'Accounting standards define how transactions are recognised, measured '
            'and disclosed so financial statements are comparable and reliable.',
    'partnership':
        'Partnership accounting adds the capital and current accounts of each '
            'partner, profit-sharing ratios, interest on capital/drawings, and '
            'the treatment of goodwill on admission or retirement.',
    'branch':
        'Branch accounts track the goods and cash sent to a branch and its '
            'result; the branch P&L is incorporated into the head-office books.',
    'assets':
        'An asset is something the business owns or controls that will bring '
            'future benefit — cash, inventory, receivables, machinery.',
    'liabilities':
        'A liability is an obligation to pay outsiders — loans, supplier dues, '
            'accrued expenses, tax payables.',
    'capital':
        'Capital is the owner\'s investment and claim against the business. '
            'Drawings reduce capital; net profit increases it.',
  };
}
