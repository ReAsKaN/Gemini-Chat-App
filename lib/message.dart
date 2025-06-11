class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      text: map['text'] as String? ?? '',
      isUser: map['isUser'] as bool? ?? false,
    );
  }
}