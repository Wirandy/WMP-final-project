import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user stream
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

  // Search user by email
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

  // Send collaboration request
  Future<void> sendCollaborationRequest(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Update target user's pendingRequestFrom field
    await _db.collection('users').doc(targetUid).update({
      'pendingRequestFrom': currentUser.uid,
    });
  }

  // Accept collaboration request
  Future<void> acceptCollaborationRequest(String requesterUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _db.batch();

    // Update current user
    final currentUserRef = _db.collection('users').doc(currentUser.uid);
    batch.update(currentUserRef, {
      'partnerId': requesterUid,
      'pendingRequestFrom': FieldValue.delete(),
    });

    // Update requester user
    final requesterRef = _db.collection('users').doc(requesterUid);
    batch.update(requesterRef, {
      'partnerId': currentUser.uid,
    });

    await batch.commit();
  }

  // Reject request
  Future<void> rejectCollaborationRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _db.collection('users').doc(currentUser.uid).update({
      'pendingRequestFrom': FieldValue.delete(),
    });
  }

  // Get user by ID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // Add Transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    final batch = _db.batch();
    final transactionRef = _db.collection('transactions').doc(); // Auto-ID

    // Set transaction data
    batch.set(transactionRef, transaction.toMap());

    // Update user balance
    final userRef = _db.collection('users').doc(transaction.userId);
    if (transaction.type == 'expense') {
      batch.update(userRef, {'balance': FieldValue.increment(-transaction.amount)});
    } else {
      batch.update(userRef, {'balance': FieldValue.increment(transaction.amount)});
    }

    await batch.commit();
  }

  // Get Transactions Stream
  Stream<List<TransactionModel>> getTransactionsStream(String myUid, String? partnerUid) {
    List<String> userIds = [myUid];
    if (partnerUid != null) {
      userIds.add(partnerUid);
    }

    return _db
        .collection('transactions')
        .where('userId', whereIn: userIds)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    });
  }
}
