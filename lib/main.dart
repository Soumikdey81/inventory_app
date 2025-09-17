import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventory_app/screens/home_screen.dart';
import 'package:inventory_app/screens/register_screen.dart';
import 'package:inventory_app/screens/login_screen.dart';
import 'package:inventory_app/screens/table_screen.dart';
import 'package:inventory_app/screens/create_table_screen.dart';
import 'package:inventory_app/screens/add_edit_row_screen.dart'; // ✅ added
import 'package:inventory_app/screens/table_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/login', // start at login
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/table': (context) => const TableScreen(),
        '/create_table': (context) => const CreateTableScreen(),

        '/add_row': (context) {
          final tableId = ModalRoute.of(context)!.settings.arguments as String;
          return AddEditRowScreen(tableId: tableId);
        },
      },
    );
  }
}
