import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../models/daily_finance_summary.dart';

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // ================= USER =================

  Stream<UserModel?> getUserStream() {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> updateUserDisplayName(String newName) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No logged in user');

    await firestore.collection('users').doc(user.uid).update({
      'displayName': newName,
    });

    await user.updateDisplayName(newName);
  }

  // ================= DAILY SUMMARY =================

  Stream<DailyFinanceSummary> getDailySummary({
    required String userId,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final end = start.add(const Duration(days: 1));

    final incomeQuery = firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'income')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end));

    final expenseQuery = firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'expense')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end));

    final userDoc = firestore.collection('users').doc(userId).snapshots();

    return incomeQuery.snapshots().asyncMap((incomeSnap) async {
      final expenseSnap = await expenseQuery.get();
      final user = await userDoc.first;

      final incomeToday = incomeSnap.docs.fold<double>(
        0,
            (sum, doc) => sum + (doc['amount'] as num).toDouble(),
      );
      final expenseToday = expenseSnap.docs.fold<double>(
        0,
            (sum, doc) => sum + (doc['amount'] as num).toDouble(),
      );
      final totalBalance =
          (user.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      return DailyFinanceSummary(
        date: targetDate,
        incomeToday: incomeToday,
        expenseToday: expenseToday,
        totalBalance: totalBalance,
      );
    });
  }

  Stream<List<CategoryAmount>> getCategoryBreakdown({
    required String userId,
    required String type, // 'income' atau 'expense'
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final end = start.add(const Duration(days: 1));

    final query = firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end));

    return query.snapshots().map((snap) {
      final Map<String, double> map = {};
      for (final doc in snap.docs) {
        final category = (doc['category'] as String?) ?? 'Lainnya';
        final amount = (doc['amount'] as num).toDouble();
        map[category] = (map[category] ?? 0) + amount;
      }
      return map.entries
          .map((e) => CategoryAmount(name: e.key, amount: e.value))
          .toList();
    });
  }

  Stream<List<DailyFinanceSummary>> getHistory({
    required String userId,
    required int days,
  }) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final query = firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));

    return query.snapshots().map((snap) {
      final Map<DateTime, Map<String, double>> map = {};

      for (final doc in snap.docs) {
        final ts = doc['date'] as Timestamp;
        final d = ts.toDate();
        final key = DateTime(d.year, d.month, d.day);
        final type = doc['type'] as String;
        final amount = (doc['amount'] as num).toDouble();

        map.putIfAbsent(key, () => {'income': 0, 'expense': 0});
        map[key]![type] = (map[key]![type] ?? 0) + amount;
      }

      final List<DailyFinanceSummary> list = [];
      for (int i = 0; i < days; i++) {
        final d = start.add(Duration(days: i));
        final data = map[DateTime(d.year, d.month, d.day)] ??
            {'income': 0, 'expense': 0};
        final income = data['income'] ?? 0;
        final expense = data['expense'] ?? 0;
        list.add(DailyFinanceSummary(
          date: d,
          incomeToday: income,
          expenseToday: expense,
          totalBalance: income - expense, // bisa kamu ganti logikanya
        ));
      }
      return list;
    });
  }
}
