import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobilproje/message.dart';
import 'package:mobilproje/models/chat.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createChat({required String title}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      DocumentReference chatDocRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .add({
        'title': title.isEmpty ? 'Yeni Sohbet' : title,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return chatDocRef.id;
    } catch (e) {
      print('Sohbet oluşturulurken hata: $e');
      return null;
    }
  }


  Future<void> saveMessage(String chatId, Message message) async {
    final user = _auth.currentUser;
    if (user == null) return;


    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': message.text,
      'isUser': message.isUser,
      'timestamp': FieldValue.serverTimestamp(),
    });


    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId)
        .update({'updatedAt': FieldValue.serverTimestamp()});
  }


  Future<List<Message>> getMessages(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return querySnapshot.docs
        .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }


  Future<List<Chat>> getChats() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {

        return Chat.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Sohbetler getirilirken hata: $e');
      return [];
    }
  }


  Future<void> deleteChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final WriteBatch batch = _firestore.batch();


    final messagesSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }


    final chatDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId);
    batch.delete(chatDocRef);


    await batch.commit();
  }


  Future<void> updateChatTitle(String chatId, String newTitle) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(chatId)
        .update({
      'title': newTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}