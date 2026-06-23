import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/screens/main_screen.dart';
import 'package:app_constructora/screens/select_company_screen.dart';
import 'package:app_constructora/screens/register_screen.dart';
import 'package:app_constructora/screens/forgot_password_screen.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'package:app_constructora/core/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@gmail.com');
  final _passwordController = TextEditingController(text: '12345');

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa correo y contraseña')),
      );
      return;
    }

    if (!Validators.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un correo electrónico válido')),
      );
      return;
    }

    try {
      // Intentar login global
      final response = await context.read<UserProvider>().loginGlobal(email, password);
      final list = response['empresas'] as List<dynamic>;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SelectCompanyScreen(
              companies: list,
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/login.png',
                  height: 200, // Un poco más grande para compensar el espacio del icono
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                
                Text('Bienvenido', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.textPrimaryColor), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Ingresa a tu cuenta para gestionar tu obra', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 48),

                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())), child: const Text('¿Olvidaste tu contraseña?')),
                  ],
                ),
                const SizedBox(height: 32),

                Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    return ElevatedButton(
                      onPressed: userProvider.isLoading ? null : _login,
                      child: userProvider.isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Iniciar Sesión'),
                    );
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? '),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())), child: const Text('Regístrate aquí')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
