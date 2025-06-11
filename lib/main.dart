import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilproje/providers/auth_provider.dart';
import 'package:mobilproje/startup.dart';
import 'package:mobilproje/themeNotifier.dart';
import 'package:mobilproje/themes.dart';
import 'package:mobilproje/homePage.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName:".env");
  runApp(
      ProviderScope(child: MyApp())
  );
}

class MyApp extends ConsumerWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref){
    final themeMode=ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: themeMode,
      home: authState.when(
        data: (user) => user == null ? const StartUp() : const HomePage(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('Hata: $error'))),
      ),
    );
  }
}
