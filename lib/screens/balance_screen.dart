import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Analysis')),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userSnapshot.data;
          if (user == null) return const Center(child: Text('User not found'));

          return StreamBuilder<List<TransactionModel>>(
            stream: firestoreService.getTransactionsStream(
              user.uid,
              user.partnerId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = snapshot.data ?? [];
              final expenses = transactions
                  .where((tx) => tx.type == 'expense')
                  .toList();

              if (expenses.isEmpty) {
                return const Center(child: Text('No expense data to analyze'));
              }

              // Calculate totals by category
              final Map<String, double> categoryTotals = {};
              double totalExpense = 0;

              for (var tx in expenses) {
                categoryTotals[tx.category] =
                    (categoryTotals[tx.category] ?? 0) + tx.amount;
                totalExpense += tx.amount;
              }

              // Prepare Pie Chart Data
              final List<PieChartSectionData> sections = categoryTotals.entries
                  .map((entry) {
                    final percentage = (entry.value / totalExpense) * 100;
                    return PieChartSectionData(
                      color:
                          Colors.primaries[categoryTotals.keys.toList().indexOf(
                                entry.key,
                              ) %
                              Colors.primaries.length],
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  })
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Expense Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Legend
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryTotals.keys.map((category) {
                        final color =
                            Colors.primaries[categoryTotals.keys
                                    .toList()
                                    .indexOf(category) %
                                Colors.primaries.length];
                        return Chip(
                          avatar: CircleAvatar(backgroundColor: color),
                          label: Text(category),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Top Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length > 5 ? 5 : expenses.length,
                      itemBuilder: (context, index) {
                        final tx = expenses[index];
                        return ListTile(
                          title: Text(tx.category),
                          subtitle: Text(
                            DateFormat('dd MMM yyyy').format(tx.date),
                          ),
                          trailing: Text(
                            'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(tx.amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
