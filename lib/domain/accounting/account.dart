/// Account categories used by the accounting engine.
enum AccountCategory {
  asset,
  liability,
  capital,
  income,
  expense;

  /// The side on which an account of this category normally increases.
  bool get normalDebit =>
      this == AccountCategory.asset || this == AccountCategory.expense;

  bool get normalCredit => !normalDebit;
}

/// A named account with a category.
class Account {
  const Account(this.name, this.category);

  final String name;
  final AccountCategory category;

  /// Whether [name] matches this account, case-insensitively and tolerating
  /// common abbreviations (e.g. "machinery" == "machinery a/c").
  bool matchesName(String other) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'\b(a/c|account|acct)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return norm(name) == norm(other);
  }

  @override
  String toString() => '$name (${category.name})';
}

/// Standard chart of accounts used by the simulator scenarios.
class ChartOfAccounts {
  ChartOfAccounts._();

  static const Account cash = Account('Cash', AccountCategory.asset);
  static const Account bank = Account('Bank', AccountCategory.asset);
  static const Account inventory = Account('Inventory', AccountCategory.asset);
  static const Account accountsReceivable =
      Account('Accounts Receivable', AccountCategory.asset);
  static const Account prepaidExpenses =
      Account('Prepaid Expenses', AccountCategory.asset);
  static const Account fixedAssets = Account('Fixed Assets', AccountCategory.asset);
  static const Account accumulatedDepreciation =
      Account('Accumulated Depreciation', AccountCategory.asset);
  static const Account inputGst = Account('Input GST', AccountCategory.asset);
  static const Account tdsReceivable = Account('TDS Receivable', AccountCategory.asset);

  static const Account accountsPayable =
      Account('Accounts Payable', AccountCategory.liability);
  static const Account outputGst = Account('Output GST', AccountCategory.liability);
  static const Account tdsPayable = Account('TDS Payable', AccountCategory.liability);
  static const Account accruedExpenses =
      Account('Accrued Expenses', AccountCategory.liability);
  static const Account bankLoan = Account('Bank Loan', AccountCategory.liability);

  static const Account capital = Account('Capital', AccountCategory.capital);
  static const Account drawings = Account('Drawings', AccountCategory.capital);
  static const Account retainedEarnings =
      Account('Retained Earnings', AccountCategory.capital);

  static const Account sales = Account('Sales Revenue', AccountCategory.income);
  static const Account serviceRevenue =
      Account('Service Revenue', AccountCategory.income);
  static const Account interestIncome =
      Account('Interest Income', AccountCategory.income);
  static const Account otherIncome = Account('Other Income', AccountCategory.income);

  static const Account purchases = Account('Purchases', AccountCategory.expense);
  static const Account costOfGoodsSold =
      Account('Cost of Goods Sold', AccountCategory.expense);
  static const Account salaries = Account('Salaries', AccountCategory.expense);
  static const Account rent = Account('Rent', AccountCategory.expense);
  static const Account utilities = Account('Utilities', AccountCategory.expense);
  static const Account depreciationExpense =
      Account('Depreciation Expense', AccountCategory.expense);
  static const Account badDebts = Account('Bad Debts', AccountCategory.expense);
  static const Account advertising = Account('Advertising', AccountCategory.expense);
  static const Account insurance = Account('Insurance', AccountCategory.expense);
  static const Account officeSupplies =
      Account('Office Supplies', AccountCategory.expense);
  static const Account interestExpense =
      Account('Interest Expense', AccountCategory.expense);
  static const Account gstExpense = Account('GST Expense', AccountCategory.expense);

  /// All accounts a learner can pick from in the simulator.
  static const List<Account> all = [
    cash,
    bank,
    inventory,
    accountsReceivable,
    prepaidExpenses,
    fixedAssets,
    accumulatedDepreciation,
    inputGst,
    tdsReceivable,
    accountsPayable,
    outputGst,
    tdsPayable,
    accruedExpenses,
    bankLoan,
    capital,
    drawings,
    retainedEarnings,
    sales,
    serviceRevenue,
    interestIncome,
    otherIncome,
    purchases,
    costOfGoodsSold,
    salaries,
    rent,
    utilities,
    depreciationExpense,
    badDebts,
    advertising,
    insurance,
    officeSupplies,
    interestExpense,
    gstExpense,
  ];

  /// Finds an account by name (tolerant match); null if unknown.
  static Account? byName(String name) {
    for (final a in all) {
      if (a.matchesName(name)) return a;
    }
    return null;
  }
}
