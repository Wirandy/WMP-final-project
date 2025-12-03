import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================= USER METHODS =================

  // Mendapatkan data user saat ini secara Realtime
  Stream<UserModel?> getUserStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Mendapatkan data satu user berdasarkan ID (Sekali panggil)
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // [BARU] Mendapatkan data BANYAK user sekaligus (Untuk fitur Grup/Family Balance)
  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    // Firestore membatasi 'whereIn' maksimal 10 ID.
    // Kita ambil 10 pertama saja untuk keamanan.
    List<String> chunk = ids.length > 10 ? ids.sublist(0, 10) : ids;

    final snapshot = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // Mencari user lain berdasarkan Email (Untuk Add Partner)
  Future<UserModel?> searchUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  // ================= COLLABORATION METHODS =================

  // [BARU] Menambah teman kolaborasi
  Future<void> addCollaborator(String currentUid, String newPartnerEmail) async {
    // 1. Cari user berdasarkan email
    final targetUser = await searchUserByEmail(newPartnerEmail);

    if (targetUser == null) {
      throw Exception('Email tidak ditemukan');
    }
    if (targetUser.uid == currentUid) {
      throw Exception('Tidak bisa menambahkan diri sendiri');
    }

    // 2. Update user kita: Tambahkan ID teman ke list 'collaborators'
    await _db.collection('users').doc(currentUid).update({
      'collaborators': FieldValue.arrayUnion([targetUser.uid])
    });

    // 3. Update user teman: Tambahkan ID kita ke list mereka
    await _db.collection('users').doc(targetUser.uid).update({
      'collaborators': FieldValue.arrayUnion([currentUid])
    });
  }

  // ================= TRANSACTION METHODS =================

  // Menambah Transaksi & Update Saldo Otomatis
  Future<void> addTransaction(TransactionModel transaction) async {
    final batch = _db.batch();
    final transactionRef = _db.collection('transactions').doc(); // Auto-Generate ID

    // 1. Simpan data transaksi
    batch.set(transactionRef, transaction.toMap());

    // 2. Update saldo user (Balance)
    final userRef = _db.collection('users').doc(transaction.userId);

    if (transaction.type == 'expense') {
      // Kalau pengeluaran, saldo berkurang
      batch.update(userRef, {'balance': FieldValue.increment(-transaction.amount)});
    } else {
      // Kalau pemasukan, saldo bertambah
      batch.update(userRef, {'balance': FieldValue.increment(transaction.amount)});
    }

    // Jalankan kedua perintah di atas secara bersamaan
    await batch.commit();
  }

  // [BARU] Mengambil List Transaksi (Gabungan Saya + Teman Kolaborasi)
  // Parameter ke-2 sekarang adalah List<String>, BUKAN String?
  Stream<List<TransactionModel>> getTransactionsStream(String myUid, List<String> collaboratorIds) {
    // Gabungkan ID saya dengan ID teman-teman
    List<String> allIds = [myUid, ...collaboratorIds];

    // Batasan Firestore: 'whereIn' maksimal 10 item
    if (allIds.length > 10) {
      allIds = allIds.sublist(0, 10);
    }

    return _db
        .collection('transactions')
        .where('userId', whereIn: allIds) // Filter transaksi milik grup
    // .orderBy('date', descending: true) // Matikan dulu jika belum ada Index
        .snapshots()
        .map((snapshot) {
      // Sortir manual di sisi aplikasi (karena orderBy dimatikan sementara)
      final docs = snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
      docs.sort((a, b) => b.date.compareTo(a.date)); // Terbaru di atas
      return docs;
    });
  }
}