// firestore_service.dart placeholder
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(Map<String, dynamic> data, String uid) async {
    await _db.collection('users').doc(uid).set(data);
  }

  Future<DocumentSnapshot> getUser(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }
}
