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
            // PERBAIKAN: Menggunakan 'user.collaborators' (List), bukan partnerId
            stream: firestoreService.getTransactionsStream(
              user.uid,
              user.collaborators,
            ),
            builder: (context, txSnapshot) {
              if (txSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = txSnapshot.data ?? [];

              return Stack(
                children: [
                  // BACKGROUND GRADIENT
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

                  // CONTENT
                  SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== HEADER =====
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Money Manager',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Welcome, ${user.displayName ?? "User"}! 👋',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                // Logout Button
                                GestureDetector(
                                  onTap: () =>
                                      context.read<AuthService>().signOut(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.logout,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ===== GROUP BALANCE CARD =====
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Icon Group & Label
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF7C4DFF,
                                              ).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.group,
                                              color: Color(0xFF7C4DFF),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Total Group Balance',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Tombol Kolaborasi
                                      IconButton(
                                        icon: const Icon(
                                          Icons.person_add_alt_1,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CollaborationScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // LOGIKA BARU: Hitung Saldo Grup (Saya + Semua Teman)
                                  FutureBuilder<List<UserModel>>(
                                    // PERBAIKAN: Menggunakan collaborators dari UserModel baru
                                    future: firestoreService.getUsersByIds(
                                      user.collaborators,
                                    ),
                                    builder: (context, collaboratorsSnapshot) {
                                      // Jika loading, tampilkan saldo sementara (hanya saldo sendiri)
                                      if (collaboratorsSnapshot
                                              .connectionState ==
                                          ConnectionState.waiting) {
                                        return _buildBalanceText(user.balance);
                                      }

                                      final collaboratorsList =
                                          collaboratorsSnapshot.data ?? [];

                                      // Hitung total saldo (Saya + Teman-teman)
                                      double totalGroupBalance = user.balance;
                                      for (var friend in collaboratorsList) {
                                        totalGroupBalance += friend.balance;
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Row: Total Saldo & Tombol Isi Saldo
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Text Total Saldo
                                              Text(
                                                NumberFormat.currency(
                                                  locale: 'id_ID',
                                                  symbol: 'Rp ',
                                                  decimalDigits: 0,
                                                ).format(totalGroupBalance),
                                                style: const TextStyle(
                                                  color: Color(0xFF00C853),
                                                  fontSize:
                                                      28, // Sedikit dikecilkan agar muat
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              // Tombol Isi Saldo
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const AddTransactionScreen(
                                                            initialType:
                                                                'income',
                                                          ),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  "Isi Saldo",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade50,
                                                  foregroundColor: Colors.green,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    30,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          const Divider(height: 1),
                                          const SizedBox(height: 16),

                                          // Rincian Saldo Saya
                                          _buildSubBalance(
                                            'My Balance',
                                            user.balance,
                                          ),
                                          const SizedBox(height: 8),

                                          // List Saldo Teman
                                          if (collaboratorsList.isNotEmpty)
                                            ...collaboratorsList.map(
                                              (friend) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4.0,
                                                ),
                                                child: _buildSubBalance(
                                                  '${friend.displayName ?? "Partner"}',
                                                  friend.balance,
                                                ),
                                              ),
                                            ),

                                          if (user.collaborators.isEmpty)
                                            const Text(
                                              "Belum ada anggota grup",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ===== DAILY CHART =====
                          _buildDailyChart(transactions),

                          const SizedBox(height: 20),

                          // ===== RECENT TRANSACTIONS =====
                          _buildRecentTransactions(transactions),

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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
        backgroundColor: const Color(0xFF2962FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ---------- WIDGET HELPER ----------

  Widget _buildBalanceText(double amount) {
    return Text(
      NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount),
      style: const TextStyle(
        color: Color(0xFF00C853),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubBalance(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          NumberFormat.compactCurrency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(amount),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------- DAILY CHART ----------

  Widget _buildDailyChart(List<TransactionModel> transactions) {
    final Map<String, double> dailyTotals = {};

    for (final tx in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      final bool isExpense = tx.type.toLowerCase() == 'expense';
      final amount = isExpense ? -tx.amount : tx.amount;
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + amount;
    }

    final sortedKeys = dailyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedKeys.isEmpty) return const SizedBox();

    final maxAbs = dailyTotals.values
        .map((v) => v.abs())
        .fold<double>(0, (prev, e) => e > prev ? e : prev);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Harian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
                      SizedBox(
                        width: 50,
                        child: Text(
                          DateFormat('dd/MM').format(DateTime.parse(key)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            if (value >= 0) const Spacer(),
                            Container(
                              width: barWidth,
                              height: 8,
                              decoration: BoxDecoration(
                                color: value >= 0 ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            if (value < 0) const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: Text(
                          NumberFormat.compact(locale: 'id_ID').format(value),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: value >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
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

  // ---------- RECENT TRANSACTIONS ----------

  Widget _buildRecentTransactions(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: Text("Belum ada transaksi")),
      );
    }

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
          const Text(
            'Transaksi Terakhir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...entry.value.map((tx) => _buildTransactionTile(tx)),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final bool isExpense = tx.type.toLowerCase() == 'expense';
    final color = isExpense ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCategoryIcon(tx.category), color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'By: ${tx.userName}',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (tx.description.isNotEmpty)
                  Text(
                    tx.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            (isExpense ? '- ' : '+ ') +
                NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(tx.amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makan':
      case 'makanan':
      case 'food':
        return Icons.restaurant;
      case 'transport':
      case 'transportasi':
        return Icons.directions_bus;
      case 'belanja':
      case 'shopping':
        return Icons.shopping_bag;
      case 'tagihan':
      case 'bills':
        return Icons.receipt_long;
      case 'gaji':
      case 'income':
        return Icons.attach_money;
      case 'kesehatan':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }
}
