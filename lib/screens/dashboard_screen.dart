import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

import 'collaboration_screen.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: Text('User data not found'));
          }

          return StreamBuilder<List<TransactionModel>>(
            stream: firestoreService.getTransactionsStream(user.uid, user.collaborators),
            builder: (context, txSnapshot) {
              final transactions = txSnapshot.data ?? [];

              return Stack(
                children: [
                  Container(
                    height: 280,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2962FF), Color(0xFFAA00FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Money Manager', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Welcome, ${user.displayName ?? "User"}! 👋', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () => context.read<AuthService>().signOut(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.logout, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ===== GROUP BALANCE CARD =====
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withOpacity(0.1), shape: BoxShape.circle),
                                            child: const Icon(Icons.group, color: Color(0xFF7C4DFF)),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Total Group Balance', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CollaborationScreen())),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // FutureBuilder untuk ambil data teman buat List di bawah & pemetaan Email
                                  FutureBuilder<List<UserModel>>(
                                      future: firestoreService.getUsersByIds([...user.collaborators, user.uid]), // Ambil Aku + Teman
                                      builder: (context, collaboratorsSnapshot) {
                                        final allUsers = collaboratorsSnapshot.data ?? [];
                                        final collaborators = allUsers.where((u) => u.uid != user.uid).toList();

                                        // Buat MAP (Kamus) ID -> Email untuk dipakai di List Transaksi nanti
                                        // ignore: unused_local_variable
                                        final Map<String, String> userEmailMap = {
                                          for (var u in allUsers) u.uid : (u.displayName ?? u.email)
                                        };

                                        // 1. Hitung TOTAL Saldo GRUP
                                        final groupTx = transactions.where((tx) => tx.isGroup).toList();
                                        double groupIncome = groupTx.where((tx) => tx.type == 'income').fold(0.0, (sum, tx) => sum + tx.amount);
                                        double groupExpense = groupTx.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);
                                        double totalGroupBalance = groupIncome - groupExpense;

                                        // 2. Hitung KONTRIBUSI SAYA
                                        final myGroupTx = groupTx.where((tx) => tx.userId == user.uid);
                                        // FIX ERROR: Menggunakan 0.0 agar tipe datanya double
                                        double myGroupIncome = myGroupTx.where((tx) => tx.type == 'income').fold(0.0, (sum, tx) => sum + tx.amount);
                                        double myGroupExpense = myGroupTx.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);
                                        double myGroupContribution = myGroupIncome - myGroupExpense;

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalGroupBalance),
                                              style: const TextStyle(color: Color(0xFF00C853), fontSize: 32, fontWeight: FontWeight.bold),
                                            ),

                                            const SizedBox(height: 24),
                                            const Divider(height: 1),
                                            const SizedBox(height: 16),

                                            _buildSubBalance(user.displayName ?? "Me", myGroupContribution),

                                            if (collaborators.isNotEmpty)
                                              ...collaborators.map((partner) {
                                                final partnerGroupTx = groupTx.where((tx) => tx.userId == partner.uid);
                                                // FIX ERROR: Menggunakan 0.0
                                                double pIncome = partnerGroupTx.where((tx) => tx.type == 'income').fold(0.0, (sum, tx) => sum + tx.amount);
                                                double pExpense = partnerGroupTx.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);
                                                double partnerContribution = pIncome - pExpense;

                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: _buildSubBalance(partner.displayName ?? partner.email, partnerContribution),
                                                );
                                              }),

                                            if (user.collaborators.isEmpty)
                                              const Padding(padding: EdgeInsets.only(top:8), child: Text("Belum ada anggota grup", style: TextStyle(color: Colors.grey, fontSize: 12))),
                                          ],
                                        );
                                      }
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildDailyChart(transactions),
                          const SizedBox(height: 20),

                          // LIST TRANSAKSI (Kita butuh data User Email)
                          FutureBuilder<List<UserModel>>(
                              future: firestoreService.getUsersByIds([...user.collaborators, user.uid]),
                              builder: (context, snap) {
                                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                final userMap = { for (var u in snap.data!) u.uid : (u.email) }; // Map ID ke Email
                                return _buildRecentTransactions(transactions, userMap);
                              }
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
        backgroundColor: const Color(0xFF2962FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSubBalance(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount), style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDailyChart(List<TransactionModel> transactions) {
    final Map<String, double> dailyTotals = {};
    for (final tx in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      final bool isExpense = tx.type.toLowerCase() == 'expense';
      final amount = isExpense ? -tx.amount : tx.amount;
      // FIX ERROR: Menggunakan 0.0 jika perlu, tapi di map biasanya aman
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0.0) + amount;
    }
    final sortedKeys = dailyTotals.keys.toList()..sort((a, b) => a.compareTo(b));
    if (sortedKeys.isEmpty) return const SizedBox();
    final maxAbs = dailyTotals.values.map((v) => v.abs()).fold<double>(0.0, (prev, e) => e > prev ? e : prev); // FIX 0.0

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Harian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Column(
              children: sortedKeys.map((key) {
                final value = dailyTotals[key]!;
                final ratio = maxAbs == 0 ? 0.0 : (value.abs() / maxAbs);
                final barWidth = 150 * ratio;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      SizedBox(width: 50, child: Text(DateFormat('dd/MM').format(DateTime.parse(key)), style: const TextStyle(fontSize: 12, color: Colors.grey))),
                      Expanded(
                        child: Row(children: [
                          if (value >= 0) const Spacer(),
                          Container(width: barWidth, height: 8, decoration: BoxDecoration(color: value >= 0 ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(8))),
                          if (value < 0) const Spacer(),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 70, child: Text(NumberFormat.compact(locale: 'id_ID').format(value), textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: value >= 0 ? Colors.green : Colors.red))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Menerima userMap untuk menampilkan Email
  Widget _buildRecentTransactions(List<TransactionModel> transactions, Map<String, String> userMap) {
    if (transactions.isEmpty) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("Belum ada transaksi")));
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in sorted) {
      final dateKey = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(tx.date);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaksi Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey))),
              ...entry.value.map((tx) => _buildTransactionTile(tx, userMap)),
              const SizedBox(height: 8),
            ]);
          }),
        ],
      ),
    );
  }

  // UPDATE: Menampilkan Email di bawah Kategori
  Widget _buildTransactionTile(TransactionModel tx, Map<String, String> userMap) {
    final bool isExpense = tx.type.toLowerCase() == 'expense';
    final color = isExpense ? Colors.red : Colors.green;

    // Ambil email dari Map, kalau tidak ada pakai userId
    final String userEmail = userMap[tx.userId] ?? "Unknown";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getCategoryIcon(tx.category), color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            // TAMPILKAN EMAIL DI SINI
            Text("By: $userEmail", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            // TAMPILKAN LABEL GRUP/PRIBADI
            if (tx.isGroup)
              Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)), child: const Text("Grup", style: TextStyle(fontSize: 10, color: Colors.purple)))
            else
              Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: const Text("Pribadi", style: TextStyle(fontSize: 10, color: Colors.blue))),
          ])),
          Text((isExpense ? '- ' : '+ ') + NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(tx.amount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makan': case 'makanan': return Icons.restaurant;
      case 'transport': return Icons.directions_bus;
      case 'belanja': return Icons.shopping_bag;
      case 'gaji': return Icons.attach_money;
      default: return Icons.category;
    }
  }
}