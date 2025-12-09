import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String description;
  final String type; // 'income' or 'expense'
  final DateTime date;
  final bool isGroup; // <--- FIELD BARU KITA

  TransactionModel({
    this.id = '',
    required this.userId,
    required this.amount,
    required this.category,
    required this.description,
    required this.type,
    required this.date,
    this.isGroup = false, // Default-nya Personal
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'Lainnya',
      description: data['description'] ?? '',
      type: data['type'] ?? 'expense',
      date: (data['date'] as Timestamp).toDate(),
      // Ambil data isGroup, kalau tidak ada dianggap false (aman untuk data lama)
      isGroup: data['isGroup'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'description': description,
      'type': type,
      'date': date,
      'isGroup': isGroup, // Simpan ke database
    };
  }
}