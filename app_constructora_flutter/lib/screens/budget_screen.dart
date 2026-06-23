import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/providers/user_provider.dart';
import 'package:app_constructora/screens/main_screen.dart';
import 'package:app_constructora/services/ia_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:app_constructora/screens/custom_camera_screen.dart';

class BudgetScreen extends StatefulWidget {
  final IaCotizacionResult? initialData;
  const BudgetScreen({super.key, this.initialData});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Variables del formulario interactivo
  final _projectNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _m2TerrenoController = TextEditingController();
  final _m2ConstruirController = TextEditingController();
  final _adicionalesController = TextEditingController();

  final List<Map<String, String>> _archivosAdjuntos = [];

  final List<String> _ambientes = ['Living', 'Comedor', 'Sala de estar', 'Estacionamiento', 'Cocina', 'Lavandería', 'Balcón/Terraza', 'Jardín', 'Vestidor'];
  final List<String> _ambientesSeleccionados = [];

  int _habitaciones = 1;
  int _banos = 1;
  
  String _materialSeleccionado = 'Estándar'; // Estándar, Premium, Lujo

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _addressController.text = data.ubicacion;
      if (data.m2Terreno > 0) _m2TerrenoController.text = data.m2Terreno.toString();
      if (data.m2Construir > 0) _m2ConstruirController.text = data.m2Construir.toString();
      _habitaciones = data.habitaciones;
      _banos = data.banos;
      if (['Estándar', 'Premium', 'Lujo'].contains(data.calidadMateriales)) {
        _materialSeleccionado = data.calidadMateriales;
      }
      for (var amb in data.ambientes) {
        if (_ambientes.contains(amb) && !_ambientesSeleccionados.contains(amb)) {
          _ambientesSeleccionados.add(amb);
        }
      }
      _adicionalesController.text = data.adicionales;
    }
  }

  String _getMaterialDescription(String material) {
    switch (material) {
      case 'Premium':
        return 'Pisos de porcelanato 90x90, grifería monocomando de diseño, aislamiento térmico avanzado, losa radiante, ventanas DVH herméticas y mesadas de cuarzo o granito.';
      case 'Lujo':
        return 'Mármoles importados, carpintería de PVC línea europea (triple vidrio), sistemas de hogar inteligente integrados, pisos de madera noble y climatización zonificada de alta gama.';
      case 'Estándar':
      default:
        return 'Construcción en ladrillo estructural, cerámicas esmaltadas 60x60, grifería tradicional de cierre cuerito y aberturas clásicas de aluminio natural.';
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _addressController.dispose();
    _m2TerrenoController.dispose();
    _m2ConstruirController.dispose();
    _adicionalesController.dispose();
    super.dispose();
  }

  void _calcularMostrarModal() {
    FocusScope.of(context).unfocus(); // Cerrar teclado
    
    final String nombreProy = _projectNameController.text.trim();
    if (nombreProy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el nombre del proyecto.')),
      );
      return;
    }

    final String ubicacion = _addressController.text.trim();
    if (ubicacion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa la ubicación del proyecto.')),
      );
      return;
    }

    final int m2Construir = int.tryParse(_m2ConstruirController.text) ?? 0;
    
    if (m2Construir <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa los M2 a construir.')));
      return;
    }

    double multiplicadorMaterial = 0;
    if (_materialSeleccionado == 'Estándar') multiplicadorMaterial = 180;
    if (_materialSeleccionado == 'Premium') multiplicadorMaterial = 320;
    if (_materialSeleccionado == 'Lujo') multiplicadorMaterial = 550;

    final double costoBase = m2Construir * multiplicadorMaterial;
    final double costoAmbientes = _ambientesSeleccionados.length * 350.0;
    final double costoHabitaciones = _habitaciones * 250.0;
    final double costoBanos = _banos * 350.0;
    const double costoEstudios = 500.0; // Costo fijo / oculto

    final double total = costoBase + costoAmbientes + costoHabitaciones + costoBanos + costoEstudios;

    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Resumen de Presupuesto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    
                    _buildSummaryItem('Costo Base (${m2Construir}m² x \$$multiplicadorMaterial)', '\$${costoBase.toStringAsFixed(2)} USD\n(Bs. ${(costoBase * 6.96).toStringAsFixed(2)})'),
                    _buildSummaryItem('Ampliaciones y Ambientes (${_ambientesSeleccionados.length})', '\$${costoAmbientes.toStringAsFixed(2)} USD\n(Bs. ${(costoAmbientes * 6.96).toStringAsFixed(2)})'),
                    _buildSummaryItem('Cuartos ($_habitaciones) y Baños ($_banos)', '\$${(costoHabitaciones + costoBanos).toStringAsFixed(2)} USD\n(Bs. ${((costoHabitaciones + costoBanos) * 6.96).toStringAsFixed(2)})'),
                    _buildSummaryItem('Estudios de terreno y factibilidad', '\$${costoEstudios.toStringAsFixed(2)} USD\n(Bs. ${(costoEstudios * 6.96).toStringAsFixed(2)})'),
                    const Divider(height: 32, thickness: 1),
                    _buildSummaryItem('TOTAL ESTIMADO', '\$${total.toStringAsFixed(2)} USD\n(Bs. ${(total * 6.96).toStringAsFixed(2)})', isBold: true),
                    
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: guardando
                          ? null
                          : () async {
                              setModalState(() => guardando = true);
                              try {
                                // Guardar cotización en la BD real
                                await context.read<UserProvider>().saveCotizacion(
                                      nombre: _projectNameController.text.trim().isNotEmpty
                                          ? _projectNameController.text.trim()
                                          : 'Proyecto Sin Nombre',
                                      ubicacion: _addressController.text.isNotEmpty ? _addressController.text : 'Ubicación no especificada',
                                      m2Terreno: int.tryParse(_m2TerrenoController.text) ?? 0,
                                      m2Construir: m2Construir,
                                      habitaciones: _habitaciones,
                                      banos: _banos,
                                      calidadMateriales: _materialSeleccionado,
                                      ambientes: _ambientesSeleccionados,
                                      adicionales: _adicionalesController.text,
                                      costoEstimado: total,
                                    );

                                // Subir archivos adjuntos si existen
                                if (_archivosAdjuntos.isNotEmpty && context.mounted) {
                                  final userProvider = context.read<UserProvider>();
                                  for (var adjunto in _archivosAdjuntos) {
                                    final path = adjunto['path'];
                                    final type = adjunto['type'];
                                    if (path != null && type != null) {
                                      await userProvider.subirArchivoProyecto(path, type);
                                    }
                                  }
                                  // Recargar datos finales del proyecto
                                  await userProvider.cargarProyectoYPagos();
                                }

                                // Éxito
                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext); // Cierra modal
                                }
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cotización y archivos guardados exitosamente.'), backgroundColor: Colors.green),
                                  );
                                  // Redirigir a pestaña Pagos
                                  context.findAncestorStateOfType<MainScreenState>()?.onItemTapped(3);
                                }
                              } catch (e) {
                                setModalState(() => guardando = false);
                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al guardar cotización: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Comenzar Proyecto (Avanzar a Pago)'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesAdjunto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
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
                  Navigator.pop(context);
                  try {
                    final pickedPath = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
                    );
                    if (pickedPath != null) {
                      setState(() {
                        _archivosAdjuntos.add({
                          'path': pickedPath,
                          'name': pickedPath.split('/').last,
                          'type': 'foto',
                        });
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error al abrir la cámara: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                title: const Text('Enviar Archivo (PDF / DWG)'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'dwg'],
                    );
                    if (result != null && result.files.single.path != null) {
                      final file = result.files.single;
                      final String ext = file.extension?.toLowerCase() ?? '';
                      setState(() {
                        _archivosAdjuntos.add({
                          'path': file.path!,
                          'name': file.name,
                          'type': ext == 'pdf' ? 'pdf' : 'dwg',
                        });
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error al seleccionar archivo: $e')),
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

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    // Estado Nuevo / Formulario Interactivo
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizar Proyecto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Datos del Proyecto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _projectNameController, decoration: const InputDecoration(labelText: 'Nombre del proyecto')),
            const SizedBox(height: 16),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Ubicación del proyecto')),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _mostrarOpcionesAdjunto,
              icon: const Icon(Icons.upload_file),
              label: const Text('Adjuntar Plano / Foto (Opcional)'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            if (_archivosAdjuntos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Archivos Seleccionados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    ..._archivosAdjuntos.map((file) {
                      IconData icon = Icons.insert_drive_file;
                      if (file['type'] == 'foto') icon = Icons.camera_alt_outlined;
                      if (file['type'] == 'pdf') icon = Icons.picture_as_pdf_outlined;
                      if (file['type'] == 'dwg') icon = Icons.architecture_outlined;
                      
                      final String name = file['name'] ?? 'Archivo';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _archivosAdjuntos.remove(file);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            const Text('Ambientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _ambientes.map((ambiente) {
                final isSelected = _ambientesSeleccionados.contains(ambiente);
                return FilterChip(
                  label: Text(ambiente),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _ambientesSeleccionados.add(ambiente);
                      } else {
                        _ambientesSeleccionados.remove(ambiente);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _habitaciones,
                    decoration: const InputDecoration(labelText: 'Habitaciones'),
                    items: [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (val) => setState(() => _habitaciones = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _banos,
                    decoration: const InputDecoration(labelText: 'Baños'),
                    items: [1, 2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (val) => setState(() => _banos = val!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text('Metros Cuadrados (m²)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _m2TerrenoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'M2 Terreno'))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _m2ConstruirController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'M2 A Construir'))),
              ],
            ),

            const SizedBox(height: 32),
            const Text('Calidad de Materiales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: ['Estándar', 'Premium', 'Lujo'].map((mat) {
                final isSelected = _materialSeleccionado == mat;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _materialSeleccionado = mat),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mat,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Detalles del material seleccionado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getMaterialDescription(_materialSeleccionado),
                      style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('Detalles Adicionales de la IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _adicionalesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Características extras mencionadas a la IA (ej. Piscina, parrillero, domótica...)',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _calcularMostrarModal,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              child: const Text('Calcular Presupuesto', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
