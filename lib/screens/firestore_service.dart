import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Stream<UserModel?> getUserStream() {
    final user = auth.currentUser;
    if (user == null) return const Stream.empty();
    return firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      // PAKAI factory yang ada di UserModel
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> updateUserDisplayName(String newName) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No logged in user');

    await firestore.collection('users').doc(user.uid).update({
      'displayName': newName,
    });

    await user.updateDisplayName(newName);
  }
}
