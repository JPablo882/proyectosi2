import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/screens/main_screen.dart';
import 'package:app_constructora/providers/user_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {'title': 'Cotiza tu casa', 'description': 'Ajusta tus requerimientos y descubre nuestras opciones de presupuesto en tiempo real.', 'icon': Icons.calculate_outlined},
    {'title': 'Sigue tu obra paso a paso', 'description': 'Monitorea con precisión la línea de tiempo y mira imágenes del progreso constructivo de tu hogar.', 'icon': Icons.construction_outlined},
    {'title': 'Gestiona tus pagos de forma segura', 'description': 'Realiza tus cuotas de reserva y pagos mensuales de forma rápida, simple y transparente.', 'icon': Icons.security_outlined},
  ];

  Future<void> _onNext() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      await context.read<UserProvider>().loginAsNewUser();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_pages[index]['icon'], size: 150, color: AppTheme.primaryColor),
                        const SizedBox(height: 48),
                        Text(_pages[index]['title'], style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(_pages[index]['description'], style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(color: _currentPage == index ? AppTheme.primaryColor : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _onNext, child: Text(_currentPage == _pages.length - 1 ? 'Comenzar' : 'Siguiente')),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
