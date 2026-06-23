import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'package:app_constructora/screens/main_screen.dart';
import 'package:app_constructora/screens/voice_prompt_screen.dart';
import 'package:app_constructora/screens/notifications_screen.dart';
import 'package:app_constructora/providers/notification_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (!userProvider.hasActiveProject) {
      // Estado vacío para nuevo usuario
      return Scaffold(
        appBar: AppBar(title: const Text('Inicio')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_work_outlined, size: 100, color: AppTheme.primaryColor),
                const SizedBox(height: 32),
                Text('Construye la casa de tus sueños', style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('Comienza tu proyecto cotizando de forma gratuita.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VoicePromptScreen(),
                        ),
                      );
                    },
                    child: const Text('Solicitar Presupuesto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Estado poblado (Usuario real con proyecto)
    Map<String, dynamic>? proximaCuota;
    for (var p in userProvider.pagosReales) {
      if (p['estado'] == 'Pendiente') {
        proximaCuota = p;
        break;
      }
    }

    String cuotaFecha = 'No hay cuotas';
    String cuotaMonto = 'Al día';
    if (proximaCuota != null) {
      final double montoCuota = (proximaCuota['monto'] as num).toDouble();
      cuotaFecha = proximaCuota['fecha'] != null
          ? proximaCuota['fecha'].toString().substring(0, 10)
          : 'Pendiente';
      cuotaMonto = '\$${montoCuota.toStringAsFixed(0)} (Bs. ${(montoCuota * 6.96).toStringAsFixed(0)})';
    }

    String nombreProyecto = userProvider.proyectoRealData != null
        ? (userProvider.proyectoRealData!['nombre'] ?? 'Proyecto Activo')
        : 'Proyecto Activo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (notificationProvider.notifications.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notificationProvider.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola, ${userProvider.userName.split(' ')[0]} 👋', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text('Aquí tienes el resumen de tu proyecto', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),

            // Selector de proyecto si tiene más de uno
            if (userProvider.misProyectosReales.length > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Ver Proyecto: ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: userProvider.idProyectoSeleccionado,
                          isExpanded: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
                          items: userProvider.misProyectosReales.map((p) {
                            return DropdownMenuItem<int>(
                              value: p['id_proyecto'],
                              child: Text(p['nombre'] ?? 'Proyecto'),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              userProvider.seleccionarProyecto(id);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildStatusCard(
              context,
              userProvider.globalProgress,
              nombreProyecto,
              userProvider.proyectoRealData?['estado'] ?? 'En curso',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoCard(context, title: 'Próxima cuota a pagar', value: cuotaFecha, subValue: cuotaMonto, icon: Icons.calendar_month_rounded, color: Colors.orange, onTap: () {
                  context.findAncestorStateOfType<MainScreenState>()?.onItemTapped(3); // Pestaña Pagos
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildInfoCard(context, title: 'Días Restantes', value: '142', subValue: 'Para entrega', icon: Icons.timer_outlined, color: Colors.green, onTap: () {
                  context.findAncestorStateOfType<MainScreenState>()?.onItemTapped(2); // Pestaña Proyecto
                })),
              ],
            ),
            const SizedBox(height: 32),
            
            // Botón para iniciar otro proyecto con la IA
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoicePromptScreen()),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                label: const Text('Iniciar otro proyecto con IA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, double progress, String nombreProyecto, String estado) {
    return GestureDetector(
      onTap: () {
        context.findAncestorStateOfType<MainScreenState>()?.onItemTapped(2); // Pestaña "Mi Obra"
      },
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nombreProyecto,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estado == 'Pendiente'
                        ? Colors.amber.shade700.withOpacity(0.8)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estado,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Estado de obra general', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(height: 16),
            Text('${progress.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress / 100, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 8)),
            const SizedBox(height: 16),
            const Text('Toca aquí para ver los detalles', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String value, required String subValue, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subValue, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }
}
