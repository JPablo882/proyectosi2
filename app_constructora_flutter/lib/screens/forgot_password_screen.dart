import 'package:flutter/material.dart';
import 'package:app_constructora/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  void _resetPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se ha enviado un enlace de recuperación a tu correo.')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Recuperar Contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset_outlined, size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 32),
                Text(
                  '¿Olvidaste tu contraseña?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu correo electrónico y te enviaremos un enlace para restablecerla.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _resetPassword,
                  child: const Text('Enviar Enlace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
