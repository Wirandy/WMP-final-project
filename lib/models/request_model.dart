import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String fromUid;
  final String fromEmail;
  final String toEmail;
  final String status; // 'pending', 'accepted', 'rejected'

  RequestModel({
    required this.id,
    required this.fromUid,
    required this.fromEmail,
    required this.toEmail,
    required this.status,
  });

  factory RequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RequestModel(
      id: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromEmail: data['fromEmail'] ?? '',
      toEmail: data['toEmail'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUid': fromUid,
      'fromEmail': fromEmail,
      'toEmail': toEmail,
      'status': status,
    };
  }
}
