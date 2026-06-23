import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/screens/main_screen.dart';
import 'package:app_constructora/providers/user_provider.dart';

class SelectCompanyScreen extends StatefulWidget {
  final List<dynamic> companies;
  final String email;

  const SelectCompanyScreen({
    super.key,
    required this.companies,
    required this.email,
  });

  @override
  State<SelectCompanyScreen> createState() => _SelectCompanyScreenState();
}

class _SelectCompanyScreenState extends State<SelectCompanyScreen> {
  int? _selectedCompanyId;

  Future<void> _confirmCompany() async {
    if (_selectedCompanyId == null) return;

    try {
      final success = await context.read<UserProvider>().seleccionarEmpresa(
            widget.email,
            _selectedCompanyId!,
          );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildCompanyLogo(String? logoBase64, bool isSelected) {
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final String base64String = logoBase64.contains(',') 
            ? logoBase64.split(',').last 
            : logoBase64;
        return ClipOval(
          child: Image.memory(
            base64Decode(base64String),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(isSelected),
          ),
        );
      } catch (e) {
        return _buildDefaultIcon(isSelected);
      }
    }
    return _buildDefaultIcon(isSelected);
  }

  Widget _buildDefaultIcon(bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.location_city,
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryColor,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.business_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Selecciona tu Empresa',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Elige la constructora con la que tienes contratado tu proyecto.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: widget.companies.isEmpty
                    ? Center(
                        child: Text(
                          'No hay empresas activas disponibles.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.companies.length,
                        itemBuilder: (context, index) {
                          final company = widget.companies[index];
                          final idEmpresa = company['id_empresa'] as int;
                          final nombre = company['nombre'] as String;
                          final logoBase64 = company['logo'] as String?;
                          final isSelected = _selectedCompanyId == idEmpresa;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCompanyId = idEmpresa;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  _buildCompanyLogo(logoBase64, isSelected),
                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Text(
                                      nombre,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  // El "redondito" (Radio selector)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.secondaryColor.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: isSelected
                                        ? Container(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.primaryColor,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedCompanyId == null || userProvider.isLoading
                    ? null
                    : _confirmCompany,
                child: userProvider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirmar Empresa'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
