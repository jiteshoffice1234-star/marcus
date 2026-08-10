import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Money utilities built on exact decimal arithmetic.
///
/// Accounting logic in this app NEVER uses `double` for amounts — floats
/// cannot represent 0.1 exactly and would silently corrupt financial math.
/// All amounts are [Decimal] (arbitrary-precision decimal) or strings.

Decimal decimalFromInt(int value) => Decimal.fromInt(value);

Decimal decimalFromString(String value) => Decimal.parse(value);

final Decimal decimalZero = Decimal.zero;
final Decimal decimalHundred = Decimal.fromInt(100);

/// Parses a user-typed amount: handles currency symbols, Indian/international
/// comma grouping, whitespace, parentheses and minus signs for negatives.
/// Returns null when the input cannot be parsed.
Decimal? tryParseAmount(String input) {
  if (input.trim().isEmpty) return null;
  var cleaned = input
      .replaceAll(RegExp(r'[,\s]'), '')
      .replaceAll('₹', '')
      .replaceAll('Rs', '')
      .replaceAll('rs', '')
      .trim();
  if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
    cleaned = '-${cleaned.substring(1, cleaned.length - 1)}';
  }
  if (cleaned.isEmpty) return null;
  try {
    // Decimal.parse only ever produces finite values from valid input.
    return Decimal.parse(cleaned);
  } on FormatException {
    return null;
  }
}

/// Formats an amount in Indian grouping (₹1,23,456.78).
String formatIndian(Decimal amount, {bool symbol = true}) {
  final formatted = NumberFormat.currency(
    locale: 'en_IN',
    symbol: symbol ? '₹' : '',
    decimalDigits: amount.hasScale ? 2 : 0,
  ).format(amount.toDouble());
  return symbol ? formatted : formatted.trim();
}

/// Formats an amount in international grouping (₹123,456.78).
String formatInternational(Decimal amount, {bool symbol = true}) {
  final formatted = NumberFormat.currency(
    locale: 'en_US',
    symbol: symbol ? '₹' : '',
    decimalDigits: amount.hasScale ? 2 : 0,
  ).format(amount.toDouble());
  return symbol ? formatted : formatted.trim();
}

/// Compact formatting for dashboard figures: ₹1.2L / ₹3.4Cr / ₹5.6K.
String formatCompact(Decimal amount) {
  final negative = amount < decimalZero;
  final abs = amount.abs();
  String suffix;
  double value;
  if (abs >= Decimal.fromInt(10000000)) {
    suffix = 'Cr';
    value = (abs / Decimal.fromInt(10000000)).toDouble();
  } else if (abs >= Decimal.fromInt(100000)) {
    suffix = 'L';
    value = (abs / Decimal.fromInt(100000)).toDouble();
  } else if (abs >= Decimal.fromInt(1000)) {
    suffix = 'K';
    value = (abs / Decimal.fromInt(1000)).toDouble();
  } else {
    suffix = '';
    value = abs.toDouble();
  }
  final rounded = value >= 100 ? value.round() : (value * 10).round() / 10;
  return '${negative ? '-' : ''}${_trimTrailingZero(rounded.toStringAsFixed(1))}$suffix';
}

String _trimTrailingZero(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

extension DecimalMoneyX on Decimal {
  bool get hasScale => toString().contains('.');

  /// True when this decimal equals [other] within a small tolerance — used for
  /// comparing user-entered answers where 50000.0 should equal 50000.
  bool closeTo(Decimal other, {Decimal? tolerance}) =>
      (this - other).abs() <= (tolerance ?? Decimal.one);
}
