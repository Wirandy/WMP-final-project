import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      appBar: AppBar(
        title: const Text('Money Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CollaborationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('User data not found'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${user.displayName ?? user.email}!',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Family Balance', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        if (user.partnerId != null)
                          FutureBuilder<UserModel?>(
                            future: firestoreService.getUser(user.partnerId!),
                            builder: (context, partnerSnapshot) {
                              if (partnerSnapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }
                              final partnerBalance = partnerSnapshot.data?.balance ?? 0.0;
                              final totalBalance = user.balance + partnerBalance;
                              
                              return Column(
                                children: [
                                  Text(
                                    'Rp ${totalBalance.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('My Balance: Rp ${user.balance.toStringAsFixed(0)}'),
                                  Text('Partner Balance: Rp ${partnerBalance.toStringAsFixed(0)}'),
                                ],
                              );
                            },
                          )
                        else
                          Text(
                            'Rp ${user.balance.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        const Divider(),
                        if (user.partnerId != null)
                          const Text('Shared Wallet (Connected)', style: TextStyle(color: Colors.grey))
                        else
                          const Text('Personal Wallet', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: StreamBuilder<List<TransactionModel>>(
                    stream: firestoreService.getTransactionsStream(user.uid, user.partnerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final transactions = snapshot.data ?? [];
                      if (transactions.isEmpty) {
                        return const Center(child: Text('No transactions yet'));
                      }

                      return ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isExpense = tx.type == 'expense';
                          return ListTile(
                            leading: Icon(
                              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                            title: Text(tx.category),
                            subtitle: Text('${DateFormat('dd MMM yyyy').format(tx.date)} • ${tx.description}'),
                            trailing: Text(
                              '${isExpense ? '-' : '+'}Rp ${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isExpense ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
