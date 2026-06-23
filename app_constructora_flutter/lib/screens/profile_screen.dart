import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/screens/login_screen.dart';
import 'package:app_constructora/screens/change_password_screen.dart';
import 'package:app_constructora/screens/notifications_screen.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAndCropImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Editar Foto',
              toolbarColor: AppTheme.primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
            IOSUiSettings(
              title: 'Editar Foto',
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ],
            ),
          ],
        );

        if (croppedFile != null) {
          context.read<UserProvider>().updateProfilePhotoPath(croppedFile.path);
        }
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndCropImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndCropImage(context, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _showPickerOptions(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: userProvider.profilePhotoPath != null 
                        ? FileImage(File(userProvider.profilePhotoPath!))
                        : null,
                    child: userProvider.profilePhotoPath == null 
                        ? const Icon(Icons.person, size: 55, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(userProvider.userName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(userProvider.userEmail, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 48),

            _buildProfileOption(context, icon: Icons.lock_outline, title: 'Cambiar Contraseña', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()))),
            _buildProfileOption(context, icon: Icons.notifications_outlined, title: 'Notificaciones', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
            _buildProfileOption(context, icon: Icons.help_outline, title: 'Soporte y Ayuda', onTap: () {}),
            
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red)),
                onPressed: () {
                  context.read<UserProvider>().logout();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
