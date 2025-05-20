import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'firebase_options.dart';

import 'package:electroshare/screens/login_screen.dart';
import 'package:electroshare/screens/home_screen.dart';
import 'package:electroshare/screens/add_screen.dart';
import 'package:electroshare/screens/my_devices.dart';
import 'package:electroshare/screens/categories.dart';
import 'package:electroshare/screens/rent_screen.dart';
import 'package:electroshare/screens/rental_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseUIAuth.configureProviders([EmailAuthProvider()]);

  runApp(const GHFlutterApp());
}

class GHFlutterApp extends StatelessWidget {
  const GHFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GHFlutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute:
          FirebaseAuth.instance.currentUser == null ? '/login' : '/home',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/my-devices': (context) => const MyDevicesScreen(),
        '/add': (context) => const AddScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/rental': (context) => const RentalScreen(),
      },
    );
  }
}
