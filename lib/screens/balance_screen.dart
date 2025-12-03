import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

enum BalancePeriod { thisMonth, lastMonth, allTime }

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  BalancePeriod _selectedPeriod = BalancePeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    const Color blueColor = Color(0xFF0054A6);
    const Color greenColor = Color(0xFF009A6C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text(
          'Financial Analysis',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return StreamBuilder<List<TransactionModel>>(
            stream: firestoreService.getTransactionsStream(
              user.uid,
              user.collaborators, // <-- Pakai collaborators (List)
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<TransactionModel> allTx = snapshot.data ?? [];

              // Filter berdasarkan periode
              final now = DateTime.now();
              DateTime start;
              DateTime end;

              switch (_selectedPeriod) {
                case BalancePeriod.thisMonth:
                  start = DateTime(now.year, now.month, 1);
                  end = DateTime(now.year, now.month + 1, 1);
                  break;
                case BalancePeriod.lastMonth:
                  final lastMonth = DateTime(now.year, now.month - 1, 1);
                  start = lastMonth;
                  end = DateTime(lastMonth.year, lastMonth.month + 1, 1);
                  break;
                case BalancePeriod.allTime:
                  start = DateTime(2000);
                  end = DateTime(2100);
                  break;
              }

              allTx = allTx
                  .where(
                    (tx) => tx.date.isAfter(start) && tx.date.isBefore(end),
                  )
                  .toList();

              final expenses = allTx
                  .where((tx) => tx.type == 'expense')
                  .toList();
              final incomes = allTx.where((tx) => tx.type == 'income').toList();

              // if (allTx.isEmpty) {
              //   return const Center(
              //     child: Text('No transaction data for this period'),
              //   );
              // }

              double totalExpense = expenses.fold(
                0,
                (sum, tx) => sum + tx.amount,
              );
              double totalIncome = incomes.fold(
                0,
                (sum, tx) => sum + tx.amount,
              );
              double netBalance = totalIncome - totalExpense;

              // Total per kategori
              final Map<String, double> categoryTotals = {
                'Makan': 0,
                'Transport': 0,
                'Belanja': 0,
                'Tagihan': 0,
                'Gaji': 0,
                'Lainnya': 0,
              };

              for (var tx in expenses) {
                if (categoryTotals.containsKey(tx.category)) {
                  categoryTotals[tx.category] =
                      categoryTotals[tx.category]! + tx.amount;
                } else {
                  categoryTotals['Lainnya'] =
                      categoryTotals['Lainnya']! + tx.amount;
                }
              }

              // Warna konsisten per kategori
              final Map<String, Color> categoryColors = {
                'Makan': const Color(0xFF00C853),
                'Transport': const Color(0xFF2962FF),
                'Belanja': const Color(0xFF6A1B9A),
                'Tagihan': const Color(0xFFFF6D00),
                'Gaji': const Color(0xFF009688),
                'Lainnya': const Color(0xFF9E9E9E),
              };

              // Data pie chart
              final sections = <PieChartSectionData>[];
              categoryTotals.forEach((cat, value) {
                if (value <= 0) return;
                final percentage = totalExpense == 0
                    ? 0
                    : (value / totalExpense) * 100;
                sections.add(
                  PieChartSectionData(
                    color: categoryColors[cat],
                    value: value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              });

              // Top 3 expenses
              final topExpenses = [...expenses]
                ..sort((a, b) => b.amount.compareTo(a.amount));
              final top3 = topExpenses.length > 3
                  ? topExpenses.sublist(0, 3)
                  : topExpenses;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [blueColor, greenColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(netBalance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _summaryChip(
                                  label: 'Income',
                                  amount: totalIncome,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryChip(
                                  label: 'Expense',
                                  amount: totalExpense,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<BalancePeriod>(
                                value: _selectedPeriod,
                                dropdownColor: Colors.white,
                                underline: const SizedBox.shrink(),
                                style: const TextStyle(color: Colors.black),
                                iconEnabledColor: Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                    value: BalancePeriod.thisMonth,
                                    child: Text('This Month'),
                                  ),
                                  DropdownMenuItem(
                                    value: BalancePeriod.lastMonth,
                                    child: Text('Last Month'),
                                  ),
                                  DropdownMenuItem(
                                    value: BalancePeriod.allTime,
                                    child: Text('All Time'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedPeriod = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Expense Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (expenses.isEmpty)
                      const Text('Belum ada data pengeluaran.')
                    else
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    sections: sections,
                                    centerSpaceRadius: 50,
                                    sectionsSpace: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Legend detail
                              Column(
                                children: categoryTotals.entries
                                    .where((e) => e.value > 0)
                                    .map((entry) {
                                      final cat = entry.key;
                                      final amount = entry.value;
                                      final percent = totalExpense == 0
                                          ? 0
                                          : (amount / totalExpense) * 100;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: categoryColors[cat],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cat,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${percent.toStringAsFixed(1)}%',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text(
                      'Top Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (top3.isEmpty)
                      const Text('Belum ada pengeluaran.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: top3.length,
                        itemBuilder: (context, index) {
                          final tx = top3[index];
                          final badge = 'TOP ${index + 1}';
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    categoryColors[tx.category] ?? Colors.grey,
                                child: const Icon(
                                  Icons.trending_down,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(tx.category),
                              subtitle: Text(
                                DateFormat('dd MMM yyyy').format(tx.date),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(tx.amount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      badge,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
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

Widget _summaryChip({
  required String label,
  required double amount,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
