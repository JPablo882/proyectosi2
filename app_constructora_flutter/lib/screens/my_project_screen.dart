import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'package:app_constructora/core/constants/api_constants.dart';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:app_constructora/screens/custom_camera_screen.dart';

class MyProjectScreen extends StatefulWidget {
  const MyProjectScreen({super.key});

  @override
  State<MyProjectScreen> createState() => _MyProjectScreenState();
}

class _MyProjectScreenState extends State<MyProjectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().cargarProyectoYPagos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final double _progress = userProvider.globalProgress;
    final proyecto = userProvider.proyectoRealData;

    if (!userProvider.hasActiveProject) {
      // Estado vacío
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Obra'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<UserProvider>().cargarProyectoYPagos(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.maps_home_work_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 24),
                      Text('Aún no tienes una obra en curso.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      SizedBox(height: 8),
                      Text('Solicita tu presupuesto para comenzar.', style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String estadoProyecto = userProvider.proyectoRealData?['estado'] ?? '';
    final String estadoNormalizado = estadoProyecto.trim().toLowerCase();

    if (estadoProyecto == 'Pendiente') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Obra'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<UserProvider>().cargarProyectoYPagos(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          'Proyecto: ',
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
                  const SizedBox(height: 24),
                ],

                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.rate_review_outlined, size: 80, color: Colors.amber.shade800),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Proyecto en Evaluación',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'La constructora está revisando la propuesta de tu obra. Una vez aprobada y en planificación, comenzaremos con los preparativos y podrás ver la línea de tiempo, los recursos asignados y los reportes de avance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Actualizar Estado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Estado con proyecto activo
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Obra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<UserProvider>().cargarProyectoYPagos(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        'Proyecto: ',
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
              // PROGRESO DE LA OBRA (ESTÁTICO PARA CLIENTE) ----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: Colors.red.shade200)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progreso de la Obra', 
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)
                        ),
                        Text(
                          '${_progress.toInt()}%',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double maxWidth = constraints.maxWidth;
                        final double dotPosition = (maxWidth * (_progress / 100.0)).clamp(0.0, maxWidth);
                        
                        return Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            // Background track
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            // Active progress track
                            Container(
                              height: 6,
                              width: dotPosition,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            // Red dot at the end
                            Positioned(
                              left: dotPosition - 10,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ---------------------------
  
              Text('Recursos en Sitio', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildPersonCard(
                context,
                proyecto?['nom_ingeniero'] ?? 'No asignado',
                'Director de Proyecto',
              ),
              const SizedBox(height: 12),
              _buildPersonCard(
                context,
                proyecto?['nom_residente'] ?? 'No asignado',
                'Residente de Obras',
              ),
              const SizedBox(height: 12),
              _buildPersonCard(
                context,
                proyecto?['nom_maestro'] ?? 'No asignado',
                'Maestro de Obra',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildResourceStat(
                      Icons.engineering,
                      '${proyecto?['cant_obreros'] ?? 0}',
                      'Obreros activos',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildResourceStat(
                      Icons.fire_truck_outlined,
                      '${proyecto?['cant_maquinaria'] ?? 0}',
                      'Maquinaria',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarOpcionesAdjunto(context, userProvider),
                    icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                    label: const Text(
                      'Adjuntar Plano / Foto (Opcional)',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Documentos del Proyecto', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _abrirPdfViewer(context, userProvider),
                      child: _buildDocCard(context, Icons.picture_as_pdf, 'Planos Arquitectónicos', 'Ver PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _abrirDwgViewer(context, userProvider),
                      child: _buildDocCard(context, Icons.view_in_ar, 'Boceto 3D y Renders', 'Ver Galería'),
                    ),
                  ),
                ],
              ),
  
              const SizedBox(height: 32),
              Text('Línea de Tiempo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              
              // Fases dependientes del estado del proyecto
              
              // Fase 1: En planificación
              _buildStateTimelineNode(
                context,
                title: 'En planificación',
                isPast: estadoNormalizado == 'en construcción' || estadoNormalizado == 'finalizado',
                isCurrent: estadoNormalizado == 'en planificación' || estadoNormalizado == 'pendiente' || estadoNormalizado == '',
                statusText: (estadoNormalizado == 'en construcción' || estadoNormalizado == 'finalizado')
                    ? 'Completado'
                    : 'En curso',
                isLast: false,
              ),
              
              // Fase 2: En construcción
              _buildStateTimelineNode(
                context,
                title: 'En construcción',
                isPast: estadoNormalizado == 'finalizado',
                isCurrent: estadoNormalizado == 'en construcción',
                statusText: estadoNormalizado == 'finalizado'
                    ? 'Completado'
                    : (estadoNormalizado == 'en construcción'
                        ? 'En curso (${_progress.toInt()}%)'
                        : 'Pendiente'),
                isLast: false,
              ),
              
              // Fase 3: Finalizado
              _buildStateTimelineNode(
                context,
                title: 'Finalizado',
                isPast: false,
                isCurrent: estadoNormalizado == 'finalizado',
                statusText: estadoNormalizado == 'finalizado'
                    ? 'Proyecto Finalizado'
                    : 'Pendiente',
                isLast: true,
              ),
              const SizedBox(height: 32),
              Text('Galería de Avances', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildGallery(_progress, userProvider),
              _buildProjectDetailsCard(context, userProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectDetailsCard(BuildContext context, UserProvider userProvider) {
    final proyecto = userProvider.proyectoRealData;
    final cotizacion = userProvider.cotizacionProyectoReal;

    if (proyecto == null) return const SizedBox.shrink();

    final String ubicacion = proyecto['ubicacion'] ?? 'Ubicación no especificada';
    final String estado = proyecto['estado'] ?? 'Pendiente';

    final String m2 = cotizacion != null ? '${cotizacion['m2_construir']} M²' : '120 M²';
    final String calidad = cotizacion != null ? 'Materiales ${cotizacion['calidad_materiales']}' : 'Materiales Lujo';
    final String habitaciones = cotizacion != null ? '${cotizacion['habitaciones']}' : '3';
    final String banos = cotizacion != null ? '${cotizacion['banos']}' : '2';
    
    String ambientes = 'Salas integradas, Jardín';
    if (cotizacion != null && cotizacion['ambientes'] != null) {
      if (cotizacion['ambientes'] is List) {
        ambientes = (cotizacion['ambientes'] as List).join(', ');
      } else if (cotizacion['ambientes'] is String) {
        ambientes = cotizacion['ambientes'];
      }
    }

    Color estadoColor = Colors.orange;
    Color estadoBgColor = Colors.orange.shade100;
    if (estado == 'Aprobado' || estado == 'En curso') {
      estadoColor = Colors.green;
      estadoBgColor = Colors.green.shade100;
    } else if (estado == 'Finalizado') {
      estadoColor = Colors.blue;
      estadoBgColor = Colors.blue.shade100;
    }

    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estado del Proyecto:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estado,
                  style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Ubicación del Proyecto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(ubicacion, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 16),
          const Text('Detalles de Construcción:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            '• $m2 de Construcción\n'
            '• $calidad\n'
            '• $habitaciones Cuartos, $banos Baños\n'
            '• $ambientes',
            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          const Divider(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Acordado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '\$${userProvider.budgetTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Descargando contrato PDF...')),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Descargar Contrato PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueGrey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryColor)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, String name, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: AppTheme.backgroundColor, child: Icon(Icons.person, size: 30, color: AppTheme.secondaryColor)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(role, style: const TextStyle(color: AppTheme.textSecondaryColor)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor), onPressed: () {})
        ],
      ),
    );
  }

  Widget _buildStateTimelineNode(
    BuildContext context, {
    required String title,
    required bool isPast,
    required bool isCurrent,
    required String statusText,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20, height: 20, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: isPast ? AppTheme.primaryColor : (isCurrent ? Colors.orange : Colors.grey.shade300), 
                border: isCurrent ? Border.all(color: Colors.orange.shade200, width: 4) : null
              )
            ),
            if (!isLast) Container(width: 2, height: 50, color: isPast ? AppTheme.primaryColor : Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                 title, 
                 style: TextStyle(
                   fontSize: 16, 
                   fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, 
                   color: isCurrent ? Colors.black87 : (isPast ? Colors.black87 : Colors.grey),
                 ),
               ),
               const SizedBox(height: 4),
               Text(
                 statusText, 
                 style: TextStyle(
                   fontSize: 13, 
                   color: isCurrent ? Colors.orange.shade800 : AppTheme.textSecondaryColor,
                 ),
               ),
               const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(double _progress, UserProvider userProvider) {
    final clientPhotos = userProvider.fotosProyecto;
    
    // Fotos fijas de la maqueta (Unsplash de alta calidad)
    final List<String> mockPhotos = [
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=800', // structural steel/concrete
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800', // workers on site
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?w=800', // foundation/blueprint
      'https://images.unsplash.com/photo-1590381105924-c72589b9ef3f?w=800', // brick wall building
      'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800', // interior/painting
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', // finished house
    ];

    int photosCount = 2; // Cimientos
    if (_progress > 33) photosCount = 4; // Obra Gruesa
    if (_progress > 66) photosCount = 6; // Acabados

    final totalItems = clientPhotos.length + photosCount;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < clientPhotos.length) {
          // Render client uploaded photo
          final photoPath = clientPhotos[index];
          final fullUrl = photoPath.startsWith('http') 
              ? photoPath 
              : '${ApiConstants.baseUrl}$photoPath';
              
          return GestureDetector(
            onTap: () => _verImagenEnPantallaCompleta(context, fullUrl, 'Foto del Cliente ${index + 1}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey.shade300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey.shade600));
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: Colors.black54,
                        child: Text(
                          'Foto Cliente ${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Render mock photo
          final mockIndex = index - clientPhotos.length;
          final mockUrl = mockIndex < mockPhotos.length ? mockPhotos[mockIndex] : mockPhotos[0];
          return GestureDetector(
            onTap: () => _verImagenEnPantallaCompleta(context, mockUrl, 'Avance ${mockIndex + 1}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey.shade300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      mockUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey.shade600));
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: Colors.black54,
                        child: Text(
                          'Avance ${mockIndex + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  void _verImagenEnPantallaCompleta(BuildContext context, String? url, String titulo) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: url != null
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: Colors.white),
                      )
                    : Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.construction, size: 100, color: Colors.white),
                            const SizedBox(height: 16),
                            Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Foto de Avance del Supervisor', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirPdfViewer(BuildContext context, UserProvider userProvider) {
    final pdfs = userProvider.documentosProyecto.where((d) => d['formato'] == 'pdf').toList();
    if (pdfs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no has adjuntado ningún Plano en PDF.')),
      );
      return;
    }
    
    final pdf = pdfs.last;
    showDialog(
      context: context,
      builder: (context) => PdfViewerDialog(
        filename: pdf['nombre'] ?? 'plano.pdf',
        fileUrl: pdf['archivo_url'] ?? '',
      ),
    );
  }

  void _abrirDwgViewer(BuildContext context, UserProvider userProvider) {
    final dwgs = userProvider.documentosProyecto.where((d) => d['formato'] == 'dwg').toList();
    if (dwgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no has adjuntado ningún Boceto 3D (DWG).')),
      );
      return;
    }
    
    final dwg = dwgs.last;
    showDialog(
      context: context,
      builder: (context) => DwgViewerDialog(
        filename: dwg['nombre'] ?? 'modelo.dwg',
        fileUrl: dwg['archivo_url'] ?? '',
      ),
    );
  }

  void _mostrarOpcionesAdjunto(BuildContext context, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar opción',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: const Text('Tomar Foto (Cámara)'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  try {
                    final pickedPath = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
                    );
                    if (pickedPath != null) {
                      // Show uploading state
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Subiendo foto...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      
                      await userProvider.subirArchivoProyecto(pickedPath, 'foto');
                      await userProvider.cargarProyectoYPagos();
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto subida y guardada en Galería de Avances.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop(); // safety close loading if open
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al procesar foto: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                title: const Text('Enviar Archivo (PDF / DWG)'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'dwg'],
                    );
                    if (result != null && result.files.single.path != null) {
                      final file = result.files.single;
                      final String ext = file.extension?.toLowerCase() ?? '';
                      
                      // Show uploading state
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Subiendo archivo...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      
                      await userProvider.subirArchivoProyecto(file.path!, ext);
                      await userProvider.cargarProyectoYPagos();
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Archivo $ext subido correctamente.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al seleccionar o subir archivo: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class PdfViewerDialog extends StatelessWidget {
  final String filename;
  final String fileUrl;
  const PdfViewerDialog({super.key, required this.filename, required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 12, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filename,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Visor de Planos PDF', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.picture_as_pdf, color: Colors.red),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0D2C6C),
              child: CustomPaint(
                painter: BlueprintPainter(),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.architecture, color: Colors.white, size: 80),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'PLANO ARQUITECTÓNICO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    filename,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'ESCALA: 1:50  |  COTIZACIÓN GENERADA',
                                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Páginas: 1 de 1', style: TextStyle(color: Colors.grey, fontSize: 14)),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace copiado al portapapeles.')),
                    );
                  },
                  icon: const Icon(Icons.link, color: AppTheme.primaryColor),
                  label: const Text('Copiar Enlace', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;
      
    const double step = 20.0;
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // Outer walls paint (thick white)
    final wallPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    // Thin wall paint
    final thinWallPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Dashed/dimension lines paint
    final dimPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 1.0;

    // Doors/windows paint
    final doorPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw house walls layout centered on canvas
    final double cx = w / 2;
    final double cy = h / 2;
    
    // House bounding rectangle: 240 x 180
    final double left = cx - 120;
    final double right = cx + 120;
    final double top = cy - 90;
    final double bottom = cy + 90;

    // Draw outer boundary walls
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), wallPaint);

    // Draw internal rooms division
    // Bedroom 1 (top-left): 100 x 90
    canvas.drawLine(Offset(left + 100, top), Offset(left + 100, top + 90), thinWallPaint);
    // Bathroom (bottom-left): 80 x 60
    canvas.drawLine(Offset(left, bottom - 60), Offset(left + 80, bottom - 60), thinWallPaint);
    canvas.drawLine(Offset(left + 80, bottom - 60), Offset(left + 80, bottom), thinWallPaint);
    
    // Kitchen (top-right): 100 x 80
    canvas.drawLine(Offset(right - 100, top), Offset(right - 100, top + 80), thinWallPaint);
    canvas.drawLine(Offset(right - 100, top + 80), Offset(right, top + 80), thinWallPaint);

    // Front door bottom center
    final frontDoorX = cx + 20;
    // Draw door arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(frontDoorX, bottom), radius: 25),
      pi,
      pi / 2,
      false,
      doorPaint,
    );
    canvas.drawLine(Offset(frontDoorX, bottom), Offset(frontDoorX - 25, bottom), doorPaint);

    // Dimension lines
    // Top dimension line
    canvas.drawLine(Offset(left, top - 15), Offset(right, top - 15), dimPaint);
    canvas.drawLine(Offset(left, top - 20), Offset(left, top - 10), dimPaint);
    canvas.drawLine(Offset(right, top - 20), Offset(right, top - 10), dimPaint);

    // Text details (Rooms names, dimensions)
    const textStyle = TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1);
    const dimStyle = TextStyle(color: Colors.cyanAccent, fontSize: 8);

    _drawText(canvas, "DORMITORIO 1\n3.00 x 3.60 m", Offset(left + 15, top + 30), textStyle);
    _drawText(canvas, "BAÑO\n2.40 x 1.80 m", Offset(left + 12, bottom - 45), textStyle);
    _drawText(canvas, "COCINA\n3.00 x 2.40 m", Offset(right - 85, top + 25), textStyle);
    _drawText(canvas, "ESTANCIA / LIVING\n4.20 x 5.40 m", Offset(cx + 10, cy + 20), textStyle);

    _drawText(canvas, "8.00 m", Offset(cx - 15, top - 28), dimStyle);
    
    // North Arrow
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(right + 30, top), 15, arrowPaint);
    canvas.drawLine(Offset(right + 30, top + 15), Offset(right + 30, top - 15), arrowPaint);
    canvas.drawLine(Offset(right + 30, top - 15), Offset(right + 26, top - 10), arrowPaint);
    canvas.drawLine(Offset(right + 30, top - 15), Offset(right + 34, top - 10), arrowPaint);
    _drawText(canvas, "N", Offset(right + 28, top - 28), const TextStyle(color: Colors.white, fontSize: 8));
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DwgViewerDialog extends StatefulWidget {
  final String filename;
  final String fileUrl;
  const DwgViewerDialog({super.key, required this.filename, required this.fileUrl});

  @override
  State<DwgViewerDialog> createState() => _DwgViewerDialogState();
}

class _DwgViewerDialogState extends State<DwgViewerDialog> {
  double _angleX = -0.5;
  double _angleY = 0.5;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 12, left: 16, right: 16),
            decoration: const BoxDecoration(
              color: Colors.black12,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.filename,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Visor CAD 3D (DWG)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.view_in_ar, color: Colors.blue),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _angleY += details.delta.dx * 0.01;
                  _angleX -= details.delta.dy * 0.01;
                });
              },
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: CustomPaint(
                  painter: DwgWireframePainter(_angleX, _angleY),
                  child: Stack(
                    children: [
                      const Positioned(
                        bottom: 16,
                        left: 16,
                        child: Text(
                          'Arrastra para orbitar 3D',
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('PERSPECTIVA ALÁMBRICA', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('FPS: 60  |  X-Y Orbit', style: TextStyle(color: Colors.grey, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Model: 3D Wireframe', style: TextStyle(color: Colors.grey, fontSize: 14)),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace copiado al portapapeles.')),
                    );
                  },
                  icon: const Icon(Icons.link, color: Colors.blue),
                  label: const Text('Copiar Enlace', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DwgWireframePainter extends CustomPainter {
  final double angleX;
  final double angleY;
  DwgWireframePainter(this.angleX, this.angleY);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.05)
      ..strokeWidth = 1.0;
    const double step = 20.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final List<List<double>> vertices = [
      [-1.0, -1.0, -0.6],
      [1.0, -1.0, -0.6],
      [1.0, 1.0, -0.6],
      [-1.0, 1.0, -0.6],
      [-1.0, -1.0, 0.4],
      [1.0, -1.0, 0.4],
      [1.0, 1.0, 0.4],
      [-1.0, 1.0, 0.4],
      [0.0, -1.0, 1.0],
      [0.0, 1.0, 1.0],
    ];

    final List<List<int>> edges = [
      [0, 1], [1, 2], [2, 3], [3, 0],
      [0, 4], [1, 5], [2, 6], [3, 7],
      [4, 5], [5, 6], [6, 7], [7, 4],
      [4, 8], [5, 8], [7, 9], [6, 9],
      [8, 9],
    ];

    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double scale = min(size.width, size.height) * 0.25;

    final double cosX = cos(angleX);
    final double sinX = sin(angleX);
    final double cosY = cos(angleY);
    final double sinY = sin(angleY);

    final List<Offset> projectedPoints = [];

    for (var v in vertices) {
      double x = v[0];
      double y = v[1];
      double z = v[2];

      double x1 = x * cosY - y * sinY;
      double y1 = x * sinY + y * cosY;
      double z1 = z;

      double x2 = x1;
      double y2 = y1 * cosX - z1 * sinX;

      double px = cx + x2 * scale;
      double py = cy - y2 * scale;

      projectedPoints.add(Offset(px, py));
    }

    for (var edge in edges) {
      final p1 = projectedPoints[edge[0]];
      final p2 = projectedPoints[edge[1]];
      canvas.drawLine(p1, p2, paint);
    }

    final axisPaint = Paint()..strokeWidth = 2.0;
    const double gizmoX = 50.0;
    final double gizmoY = size.height - 50.0;
    const double gizmoLen = 20.0;

    final List<List<double>> axes = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0],
    ];

    final List<Color> axisColors = [Colors.red, Colors.green, Colors.blue];

    for (int i = 0; i < 3; i++) {
      double x = axes[i][0];
      double y = axes[i][1];
      double z = axes[i][2];

      double x1 = x * cosY - y * sinY;
      double y1 = x * sinY + y * cosY;
      double z1 = z;

      double x2 = x1;
      double y2 = y1 * cosX - z1 * sinX;

      final p = Offset(gizmoX + x2 * gizmoLen, gizmoY - y2 * gizmoLen);
      axisPaint.color = axisColors[i];
      canvas.drawLine(Offset(gizmoX, gizmoY), p, axisPaint);
    }
  }

  @override
  bool shouldRepaint(DwgWireframePainter oldDelegate) {
    return oldDelegate.angleX != angleX || oldDelegate.angleY != angleY;
  }
}
