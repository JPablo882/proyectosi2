import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'package:app_constructora/screens/home_screen.dart';
import 'package:app_constructora/screens/budget_screen.dart';
import 'package:app_constructora/screens/my_project_screen.dart';
import 'package:app_constructora/screens/payments_screen.dart';
import 'package:app_constructora/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    HomeScreen(),
    BudgetScreen(),
    MyProjectScreen(),
    PaymentsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().cargarProyectoYPagos();
      context.read<UserProvider>().verificarCotizacionPendiente();
    });
  }

  void onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Trigger reloading of project and payments data in the background to ensure it's always up-to-date!
    context.read<UserProvider>().cargarProyectoYPagos();
    context.read<UserProvider>().verificarCotizacionPendiente();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate_rounded), label: 'Presupuesto'),
          BottomNavigationBarItem(icon: Icon(Icons.construction_outlined), activeIcon: Icon(Icons.construction_rounded), label: 'Mi Obra'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Pagos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
