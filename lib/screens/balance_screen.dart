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
  bool _isGroupMode = false; // Toggle: False = Pribadi, True = Grup

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    // Warna Gradient Personal (Biru-Hijau) vs Grup (Ungu-Pink)
    final List<Color> gradientColors = _isGroupMode
        ? [const Color(0xFF7C4DFF), const Color(0xFFE040FB)] // Warna Grup
        : [const Color(0xFF0054A6), const Color(0xFF009A6C)]; // Warna Pribadi

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          _isGroupMode ? 'Group Analysis' : 'Personal Analysis',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          // TOMBOL GANTI MODE (PRIBADI / GRUP)
          Row(
            children: [
              Text(
                _isGroupMode ? "Grup" : "Pribadi",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _isGroupMode,
                activeColor: Colors.purple,
                onChanged: (val) {
                  setState(() {
                    _isGroupMode = val;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
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
              user.collaborators,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<TransactionModel> allTx = snapshot.data ?? [];

              // 1. FILTER BERDASARKAN MODE (PRIBADI / GRUP)
              if (_isGroupMode) {
                // Mode Grup: Ambil semua transaksi yang isGroup == true
                allTx = allTx.where((tx) => tx.isGroup).toList();
              } else {
                // Mode Pribadi: Ambil transaksi user sendiri DAN bukan grup
                allTx = allTx.where((tx) => tx.userId == user.uid && !tx.isGroup).toList();
              }

              // 2. FILTER BERDASARKAN PERIODE WAKTU
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

              allTx = allTx.where((tx) => tx.date.isAfter(start) && tx.date.isBefore(end)).toList();

              final expenses = allTx.where((tx) => tx.type == 'expense').toList();
              final incomes = allTx.where((tx) => tx.type == 'income').toList();

              double totalExpense = expenses.fold(0, (sum, tx) => sum + tx.amount);
              double totalIncome = incomes.fold(0, (sum, tx) => sum + tx.amount);
              double netBalance = totalIncome - totalExpense;

              // Total per kategori untuk Pie Chart
              final Map<String, double> categoryTotals = {};
              for (var tx in expenses) {
                categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
              }

              // Warna Kategori
              final Map<String, Color> categoryColors = {
                'Makan': const Color(0xFF00C853),
                'Transport': const Color(0xFF2962FF),
                'Belanja': const Color(0xFF6A1B9A),
                'Tagihan': const Color(0xFFFF6D00),
                'Gaji': const Color(0xFF009688),
                'Lainnya': const Color(0xFF9E9E9E),
              };

              final sections = <PieChartSectionData>[];
              categoryTotals.forEach((cat, value) {
                if (value <= 0) return;
                final percentage = totalExpense == 0 ? 0 : (value / totalExpense) * 100;
                sections.add(
                  PieChartSectionData(
                    color: categoryColors[cat] ?? Colors.grey,
                    value: value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
              });

              final topExpenses = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));
              final top3 = topExpenses.length > 3 ? topExpenses.sublist(0, 3) : topExpenses;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KARTU SALDO UTAMA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isGroupMode ? 'Overall Group Balance' : 'My Personal Balance',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(netBalance)}',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _summaryChip(label: 'Income', amount: totalIncome, color: Colors.greenAccent)),
                              const SizedBox(width: 8),
                              Expanded(child: _summaryChip(label: 'Expense', amount: totalExpense, color: Colors.redAccent)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Dropdown Periode
                          Align(
                            alignment: Alignment.centerRight,
                            child: DropdownButton<BalancePeriod>(
                              value: _selectedPeriod,
                              dropdownColor: Colors.white,
                              underline: const SizedBox.shrink(),
                              style: const TextStyle(color: Colors.black), // Teks hitam saat dropdown dibuka
                              selectedItemBuilder: (BuildContext context) {
                                return [
                                  const Text('This Month', style: TextStyle(color: Colors.white)),
                                  const Text('Last Month', style: TextStyle(color: Colors.white)),
                                  const Text('All Time', style: TextStyle(color: Colors.white)),
                                ].map((e) => DropdownMenuItem(value: e.data, child: e)).toList().cast<Widget>();
                              },
                              iconEnabledColor: Colors.white,
                              items: const [
                                DropdownMenuItem(value: BalancePeriod.thisMonth, child: Text('This Month')),
                                DropdownMenuItem(value: BalancePeriod.lastMonth, child: Text('Last Month')),
                                DropdownMenuItem(value: BalancePeriod.allTime, child: Text('All Time')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPeriod = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text('Expense Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    if (expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('Belum ada data pengeluaran.')),
                      )
                    else
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(sections: sections, centerSpaceRadius: 50, sectionsSpace: 2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: categoryTotals.entries.where((e) => e.value > 0).map((entry) {
                                  final cat = entry.key;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 14, height: 14,
                                          decoration: BoxDecoration(color: categoryColors[cat] ?? Colors.grey, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w500))),
                                        Text('Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(entry.value)}'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text('Top Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: categoryColors[tx.category] ?? Colors.grey,
                                child: Icon(_getIcon(tx.category), color: Colors.white, size: 20),
                              ),
                              title: Text(tx.category),
                              subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date)),
                              trailing: Text(
                                'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(tx.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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

  Widget _summaryChip({required String label, required double amount, required Color color}) {
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Rp ${NumberFormat.compactCurrency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makan': return Icons.fastfood;
      case 'transport': return Icons.directions_bus;
      case 'belanja': return Icons.shopping_bag;
      case 'gaji': return Icons.attach_money;
      default: return Icons.category;
    }
  }
}