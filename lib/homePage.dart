import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mobilproje/message.dart';
import 'package:mobilproje/themeNotifier.dart';
import 'package:mobilproje/providers/auth_provider.dart';
import 'package:mobilproje/startup.dart';
import 'package:mobilproje/services/chat_service.dart';
import 'package:mobilproje/models/chat.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ChatService _chatService = ChatService();

  bool _isSendingMessage = false;
  bool _isLoadingChats = true;
  bool _isLoadingMessages = false;

  List<Chat> _chats = [];
  String? _currentChatId;


  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserChats();
  }


  Future<void> _loadUserChats() async {
    setState(() {
      _isLoadingChats = true;
    });
    final chats = await _chatService.getChats();
    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoadingChats = false;

        if (_currentChatId != null && !_chats.any((chat) => chat.id == _currentChatId)) {
          _currentChatId = null;
          _messages.clear();
        }
      });
    }
  }


  Future<void> _loadChatMessages(String chatId) async {
    if (chatId.isEmpty) return;
    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
    });
    final messages = await _chatService.getMessages(chatId);
    if (mounted) {
      setState(() {
        _messages.addAll(messages);
        _isLoadingMessages = false;
      });
    }
  }


  Future<void> _createNewChat() async {
    String? title = await _showChatTitleDialog();

    if (title == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet oluşturma iptal edildi.')),
      );
      return;
    }


    setState(() => _isSendingMessage = true);
    final newChatId = await _chatService.createChat(title: title ?? "Yeni Sohbet");
    if (mounted) {
      setState(() => _isSendingMessage = false);
    }

    if (newChatId != null) {
      await _loadUserChats();
      if (mounted) {
        setState(() {
          _currentChatId = newChatId;
          _currentIndex = 1;
          _messages.clear();
          _isLoadingMessages = true;
        });
        _loadChatMessages(newChatId).then((_) {
          if (mounted) {
            setState(() => _isLoadingMessages = false);
          }
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sohbet oluşturulamadı.')),
        );
      }
    }
  }

  Future<String?> _showChatTitleDialog() async {
    TextEditingController titleController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sohbet Başlığı'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: "Sohbet başlığı (isteğe bağlı)"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          TextButton(
            child: const Text('Oluştur'),
            onPressed: () => Navigator.of(context).pop(titleController.text.trim()),
          ),
        ],
      ),
    );
  }


  Future<void> _confirmDeleteChat(Chat chatToDelete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti Sil'),
        content: Text('"${chatToDelete.title}" başlıklı sohbeti ve tüm mesajlarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: Theme.of(context).textTheme.bodyLarge,),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingChats = true);
      await _chatService.deleteChat(chatToDelete.id);

      if (mounted) {
        if (_currentChatId == chatToDelete.id) {
          _currentChatId = null;
          _messages.clear();

          if (_chats.length > 1) {
            // _currentIndex = 0;
          } else {
            _currentIndex = 0;
          }
        }
        await _loadUserChats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${chatToDelete.title}" sohbeti silindi.')),
        );
      }
    }
  }


  Future<void> callGeminiModel() async {
    if (_currentChatId == null || _currentChatId!.isEmpty) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir sohbet seçin veya yeni bir sohbet oluşturun.')),
        );
      }
      return;
    }

    if (_controller.text.isNotEmpty) {
      final userMessage = Message(text: _controller.text, isUser: true);
      setState(() {
        _messages.add(userMessage);
        _isSendingMessage = true;
      });
      _controller.clear();

      try {
        await _chatService.saveMessage(_currentChatId!, userMessage);

        final model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: dotenv.env['GOOGLE_API_KEY']!,
        );
        final prompt = userMessage.text.trim();
        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);

        final botMessage = Message(text: response.text ?? 'Bir sorun oluştu.', isUser: false);
        if (mounted) {
          setState(() {
            _messages.add(botMessage);
          });
        }
        await _chatService.saveMessage(_currentChatId!, botMessage);
      } catch (e) {
        print('Gemini Hatası: $e');
        final errorMessage = Message(text: 'Üzgünüm, bir hata oluştu. $e', isUser: false);
        if (mounted) {
          setState(() {
            _messages.add(errorMessage);
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSendingMessage = false;
          });
        }
      }
    }
  }



  Widget _buildProfileScreen() {
    final user = ref.watch(authStateProvider).value;

    final TextEditingController _newPasswordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setStateInsideBuilder) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(user?.email ?? 'Email bulunamadı',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              const Divider(height: 40),
              Text('Şifre Değiştir', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {

                  final newPassword = _newPasswordController.text;
                  final confirmPassword = _confirmPasswordController.text;

                  if (newPassword.isEmpty || confirmPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm şifre alanlarını doldurun.')),
                    );
                    return;
                  }
                  if (newPassword.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yeni şifre en az 6 karakter olmalıdır.')),
                    );
                    return;
                  }
                  if (newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifreler eşleşmiyor!')),
                    );
                    return;
                  }

                  try {
                    await user?.updatePassword(newPassword);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifre başarıyla değiştirildi.')),
                    );
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Şifre değiştirilemedi: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Şifreyi Güncelle'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ref.read(authServiceProvider).signOut();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const StartUp()),
                            (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildChatListScreen() {
    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text('Henüz bir sohbet başlatmadınız.',style:Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Yeni Sohbet Başlat'),
              onPressed: _createNewChat,
            )
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Text(chat.title.isNotEmpty ? chat.title[0].toUpperCase() : 'S', style: TextStyle(color: Theme.of(context).colorScheme.primary),),
            ),
            title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis,),
            subtitle: Text(
              'Son mesaj: ${chat.updatedAt.toDate().day}/${chat.updatedAt.toDate().month}/${chat.updatedAt.toDate().year}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              onPressed: () => _confirmDeleteChat(chat),
              tooltip: 'Sohbeti Sil',
            ),
            onTap: () {
              setState(() {
                _currentChatId = chat.id;
                _isLoadingMessages = true;
                _currentIndex = 1;
              });
              _loadChatMessages(chat.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveChatScreen() {
    if (_currentChatId == null || _currentChatId!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
             Text('Başlamak için bir sohbet seçin\nveya yeni bir sohbet oluşturun.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
              child: const Text('Sohbetleri Görüntüle'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _createNewChat,
              child: const Text('Yeni Sohbet Başlat'),
            )
          ],
        ),
      );
    }

    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentChatTitle = _chats.firstWhere(
            (chat) => chat.id == _currentChatId,
        orElse: () => Chat(id: '', title: 'Sohbet', createdAt: Timestamp.now(), updatedAt: Timestamp.now()) // Bulamazsa varsayılan
    ).title;


    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    currentChatTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
                          : Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(0),
                        bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(16),
                      )
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Theme.of(context).textTheme.bodySmall?.color ?? Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isSendingMessage) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
        Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 8, left: 16, right: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'Bir mesaj yazın...',
                      hintStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => callGeminiModel(),
                  ),
                ),
                IconButton(
                  icon: Image.asset('assets/send.png', color: Theme.of(context).colorScheme.primary, width: 24, height: 24),
                  onPressed: _isSendingMessage ? null : callGeminiModel,
                  tooltip: 'Gönder',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);

    Widget currentScreenBody;
    switch (_currentIndex) {
      case 0:
        currentScreenBody = _buildChatListScreen();
        break;
      case 1:
        currentScreenBody = _buildActiveChatScreen();
        break;
      case 2:
        currentScreenBody = _buildProfileScreen();
        break;
      default:
        currentScreenBody = _buildChatListScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0.5,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset('assets/gpt-robot.png', height: 30),
                const SizedBox(width: 8),
                Text('Gemini Sohbet', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            IconButton(
              icon: (currentTheme == ThemeMode.dark)
                  ? Icon(Icons.light_mode, color: Theme.of(context).colorScheme.secondary)
                  : Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                ref.read(themeProvider.notifier).toggleTheme();
              },
              tooltip: 'Temayı Değiştir',
            )
          ],
        ),
      ),
      body: currentScreenBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        elevation: 2,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          if (_currentIndex == 1 && (index == 0 || index == 2)) {
            // _messages.clear();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Sohbetler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Aktif Sohbet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _createNewChat,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Yeni Sohbet'),
        tooltip: 'Yeni Sohbet Başlat',
      )
          : null,
    );
  }
}