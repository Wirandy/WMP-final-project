import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/request_model.dart';

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
  Future<void> addCollaborator(
    String currentUid,
    String newPartnerEmail,
  ) async {
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
      'collaborators': FieldValue.arrayUnion([targetUser.uid]),
    });

    // 3. Update user teman: Tambahkan ID kita ke list mereka
    await _db.collection('users').doc(targetUser.uid).update({
      'collaborators': FieldValue.arrayUnion([currentUid]),
    });
  }

  // [BARU] Menghapus anggota grup
  Future<void> removeCollaborator(String currentUid, String targetUid) async {
    // 1. Hapus ID teman dari list kita
    await _db.collection('users').doc(currentUid).update({
      'collaborators': FieldValue.arrayRemove([targetUid]),
    });

    // 2. Hapus ID kita dari list teman (agar adil/putus hubungan kedua arah)
    await _db.collection('users').doc(targetUid).update({
      'collaborators': FieldValue.arrayRemove([currentUid]),
    });
  }

  // [BARU] Set PIN Keamanan
  Future<void> setPin(String uid, String pin) async {
    await _db.collection('users').doc(uid).update({'pin': pin});
  }

  // ================= TRANSACTION METHODS =================

  // Menambah Transaksi & Update Saldo Otomatis
  Future<void> addTransaction(TransactionModel transaction) async {
    final batch = _db.batch();
    final transactionRef = _db
        .collection('transactions')
        .doc(); // Auto-Generate ID

    // 1. Simpan data transaksi
    batch.set(transactionRef, transaction.toMap());

    // 2. Update saldo user (Balance)
    final userRef = _db.collection('users').doc(transaction.userId);

    if (transaction.type == 'expense') {
      // Kalau pengeluaran, saldo berkurang
      batch.update(userRef, {
        'balance': FieldValue.increment(-transaction.amount),
      });
    } else {
      // Kalau pemasukan, saldo bertambah
      batch.update(userRef, {
        'balance': FieldValue.increment(transaction.amount),
      });
    }

    // Jalankan kedua perintah di atas secara bersamaan
    await batch.commit();
  }

  // [BARU] Mengambil List Transaksi (Gabungan Saya + Teman Kolaborasi)
  // Parameter ke-2 sekarang adalah List<String>, BUKAN String?
  Stream<List<TransactionModel>> getTransactionsStream(
    String myUid,
    List<String> collaboratorIds,
  ) {
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
          final docs = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
          docs.sort((a, b) => b.date.compareTo(a.date)); // Terbaru di atas
          return docs;
        });
  }
  // ================= REQUEST METHODS =================

  // Kirim Request
  Future<void> sendCollaborationRequest(
    String fromUid,
    String fromEmail,
    String toEmail,
  ) async {
    // 1. Cari user tujuan
    final targetUser = await searchUserByEmail(toEmail);
    if (targetUser == null) throw Exception('Email tidak ditemukan');
    if (targetUser.uid == fromUid)
      throw Exception('Tidak bisa menambahkan diri sendiri');

    // 2. Cek apakah sudah ada request pending
    final existing = await _db
        .collection('requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toEmail', isEqualTo: toEmail)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty)
      throw Exception('Request sudah dikirim sebelumnya');

    // [BARU] 3. Cek apakah user SUDAH menjadi collaborator
    final senderDoc = await _db.collection('users').doc(fromUid).get();
    if (senderDoc.exists) {
      final senderData = UserModel.fromFirestore(senderDoc);
      if (senderData.collaborators.contains(targetUser.uid)) {
        throw Exception('User ini sudah ada di dalam grup Anda');
      }
    }

    // 4. Buat request baru
    await _db.collection('requests').add({
      'fromUid': fromUid,
      'fromEmail': fromEmail,
      'toEmail': toEmail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Ambil Request Masuk
  Stream<List<RequestModel>> getIncomingRequests(String myEmail) {
    return _db
        .collection('requests')
        .where('toEmail', isEqualTo: myEmail)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RequestModel.fromFirestore(doc)).toList(),
        );
  }

  // Terima Request (Updated: Bi-Directional Mesh Logic)
  Future<void> acceptRequest(
    String requestId,
    String fromUid,
    String myUid,
  ) async {
    final batch = _db.batch();

    // 1. Ambil data KEDUA PIHAK (Pengirim & Penerima)
    final senderDoc = await _db.collection('users').doc(fromUid).get();
    final receiverDoc = await _db.collection('users').doc(myUid).get();

    if (!senderDoc.exists || !receiverDoc.exists)
      throw Exception("Data user tidak ditemukan");

    final senderData = UserModel.fromFirestore(senderDoc);
    final receiverData = UserModel.fromFirestore(receiverDoc);

    final List<String> senderFriends = senderData.collaborators;
    final List<String> receiverFriends = receiverData.collaborators;

    // 2. Update status request
    final reqRef = _db.collection('requests').doc(requestId);
    batch.update(reqRef, {'status': 'accepted'});

    // 3. Hubungkan UTAMA (Sender <-> Receiver)
    final senderRef = _db.collection('users').doc(fromUid);
    final receiverRef = _db.collection('users').doc(myUid);

    batch.update(receiverRef, {
      'collaborators': FieldValue.arrayUnion([fromUid]),
    });
    batch.update(senderRef, {
      'collaborators': FieldValue.arrayUnion([myUid]),
    });

    // 4. MESH LOGIC: Gabungkan Semua Teman

    // A. Hubungkan SENDER ke semua teman RECEIVER
    for (String friendId in receiverFriends) {
      if (friendId == fromUid) continue; // Skip jika sudah ada

      final friendRef = _db.collection('users').doc(friendId);

      // Tambahkan Sender ke Teman Receiver
      batch.update(friendRef, {
        'collaborators': FieldValue.arrayUnion([fromUid]),
      });
      // Tambahkan Teman Receiver ke Sender
      batch.update(senderRef, {
        'collaborators': FieldValue.arrayUnion([friendId]),
      });
    }

    // B. Hubungkan RECEIVER ke semua teman SENDER
    for (String friendId in senderFriends) {
      if (friendId == myUid) continue;

      final friendRef = _db.collection('users').doc(friendId);

      // Tambahkan Receiver ke Teman Sender
      batch.update(friendRef, {
        'collaborators': FieldValue.arrayUnion([myUid]),
      });
      // Tambahkan Teman Sender ke Receiver
      batch.update(receiverRef, {
        'collaborators': FieldValue.arrayUnion([friendId]),
      });
    }

    await batch.commit();
  }

  // Tolak Request
  Future<void> rejectRequest(String requestId) async {
    await _db.collection('requests').doc(requestId).update({
      'status': 'rejected',
    });
  }
}
