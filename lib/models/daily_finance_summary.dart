import 'package:flutter/foundation.dart';

class DailyFinanceSummary {
  final DateTime date;
  final double incomeToday;
  final double expenseToday;
  final double totalBalance;

  DailyFinanceSummary({
    required this.date,
    required this.incomeToday,
    required this.expenseToday,
    required this.totalBalance,
  });
}

class CategoryAmount {
  final String name;
  final double amount;

  CategoryAmount({
    required this.name,
    required this.amount,
  });
}
