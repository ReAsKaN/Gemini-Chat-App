import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String title;
  final Timestamp createdAt;
  final Timestamp updatedAt;


  Chat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });


  factory Chat.fromMap(String id, Map<String, dynamic> data) {
    return Chat(
      id: id,
      title: data['title'] ?? 'Başlıksız Sohbet',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),


    );
  }
}