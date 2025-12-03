import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final double balance;
  // GANTI: Dari partnerId (String) menjadi collaborators (List)
  final List<String> collaborators;
  final String? pendingRequestFrom;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.balance = 0.0,
    this.collaborators = const [], // Default list kosong
    this.pendingRequestFrom,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      balance: (data['balance'] ?? 0.0).toDouble(),
      // LOGIKA BARU: Mengambil array dari Firestore dan mengubahnya jadi List<String>
      collaborators: List<String>.from(data['collaborators'] ?? []),
      pendingRequestFrom: data['pendingRequestFrom'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'balance': balance,
      'collaborators': collaborators, // Simpan sebagai list ke database
      'pendingRequestFrom': pendingRequestFrom,
    };
  }
}