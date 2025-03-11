import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createDocument(String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).set(data);
  }

  Future<DocumentSnapshot> readDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).get();
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }

  Stream<QuerySnapshot> getCollectionStream(String collection) {
    return _db.collection(collection).snapshots();
  }
}
