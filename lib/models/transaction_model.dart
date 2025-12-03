import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'expense' or 'income'
  final String category;
  final DateTime date;
  final String description;
  final String userName;
  final bool isShared;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.description,
    this.isShared = false,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'expense',
      category: data['category'] ?? 'General',
      date: (data['date'] is Timestamp)
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] ?? '',
      isShared: data['isShared'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'type': type,
      'category': category,
      'date': Timestamp.fromDate(date),
      'description': description,
      'isShared': isShared,
    };
  }
}
