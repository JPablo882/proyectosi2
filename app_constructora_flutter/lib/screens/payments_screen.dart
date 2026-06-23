import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/providers/user_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedPlan = 'directo'; // 'directo' or 'mensual'
  int _selectedMonths = 10;
  bool _submittingPlan = false;
  bool _processingPayment = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    // Determinar qué vista mostrar según el estado real del proyecto
    final bool tieneProyecto = userProvider.tieneProyectoReal;
    final String estadoProyecto = userProvider.proyectoRealData?['estado'] ?? '';
    final List<dynamic> listado = userProvider.pagosReales;

    // Caso A: No hay ningún proyecto
    if (!tieneProyecto) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'No hay pagos pendientes.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuando solicites un presupuesto y sea enviado a la empresa, aparecerá aquí tu plan de pagos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Caso B: Proyecto en estado 'Pendiente' (Esperando Aprobación)
    if (estadoProyecto == 'Pendiente') {
      final double total = userProvider.budgetTotal;
      final String nombreProyecto = userProvider.proyectoRealData?['nombre'] ?? 'Proyecto Solicitado';
      final String ubicacion = userProvider.proyectoRealData?['ubicacion'] ?? 'No especificada';

      return Scaffold(
        appBar: AppBar(
          title: const Text('Evaluación de Proyecto'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
                const SizedBox(height: 20),
              ],

              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_empty_rounded, size: 55, color: Colors.amber.shade800),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Esperando Aprobación',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu solicitud de obra ha sido enviada. Estamos evaluando los detalles técnicos y de factibilidad.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Detalles de la cotización enviada
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen del Proyecto Enviado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Divider(height: 20),
                    _buildDetailRow('Nombre:', nombreProyecto),
                    const SizedBox(height: 8),
                    _buildDetailRow('Ubicación:', ubicacion),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Costo Estimado:',
                      '\$${total.toStringAsFixed(2)} USD\n(Bs. ${(total * 6.96).toStringAsFixed(2)})',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Línea de tiempo de aprobación
              const Text('Flujo de Aprobación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildApprovalStep(
                title: '1. Solicitud Recibida',
                subtitle: 'La cotización se guardó y se generó la propuesta.',
                isDone: true,
                isActive: false,
              ),
              _buildApprovalStep(
                title: '2. Evaluación de la Empresa',
                subtitle: 'La constructora está revisando los planos y costos.',
                isDone: false,
                isActive: true,
              ),
              _buildApprovalStep(
                title: '3. Selección de Plan de Pago',
                subtitle: 'Se habilitará cuando el proyecto pase a "En planificación".',
                isDone: false,
                isActive: false,
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
                icon: const Icon(Icons.sync),
                label: const Text('Actualizar Estado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Caso C: Proyecto Aprobado ('En planificación') pero sin plan de pagos aún
    if (listado.isEmpty) {
      final double total = userProvider.budgetTotal;
      final double reserva = total * 0.05;
      final double financiado = total * 0.95;
      final double cuotaMensual = financiado / _selectedMonths;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Completar Plan de Pago'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
                const SizedBox(height: 20),
              ],

              const Icon(Icons.payment_rounded, size: 70, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Elige tu Plan de Pago',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu obra ha sido aprobada. Selecciona la forma en que deseas financiar y realizar el pago para iniciar la construcción.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // CARD PLAN DIRECTO
              GestureDetector(
                onTap: () => setState(() => _selectedPlan = 'directo'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedPlan == 'directo'
                        ? AppTheme.primaryColor.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedPlan == 'directo'
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: 'directo',
                        groupValue: _selectedPlan,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) => setState(() => _selectedPlan = val!),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pago Directo Completo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paga el 100% de la obra de forma directa y simplificada.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD PLAN MENSUAL
              GestureDetector(
                onTap: () => setState(() => _selectedPlan = 'mensual'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedPlan == 'mensual'
                        ? AppTheme.primaryColor.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedPlan == 'mensual'
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'mensual',
                            groupValue: _selectedPlan,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) => setState(() => _selectedPlan = val!),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'A Pucho Mensual (Financiado)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Paga una reserva del 5% y el resto en cómodas cuotas mensuales.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPlan == 'mensual') ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cantidad de meses:', style: TextStyle(fontWeight: FontWeight.w500)),
                            DropdownButton<int>(
                              value: _selectedMonths,
                              items: [3, 6, 10, 12, 18, 24].map((m) {
                                return DropdownMenuItem<int>(
                                  value: m,
                                  child: Text('$m meses'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedMonths = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // DETALLE DEL PRESUPUESTO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text('Monto Total del Proyecto', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '\$${total.toStringAsFixed(2)} USD\n(Bs. ${(total * 6.96).toStringAsFixed(2)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const Divider(height: 24),
                     if (_selectedPlan == 'directo') ...[
                      _buildDetailRow(
                        'Pago Único Pendiente',
                        '\$${total.toStringAsFixed(2)} USD\n(Bs. ${(total * 6.96).toStringAsFixed(2)})',
                        isBold: true,
                        color: AppTheme.primaryColor,
                      ),
                    ] else ...[
                      _buildDetailRow('Reserva Inicial (5%)', '\$${reserva.toStringAsFixed(2)} USD\n(Bs. ${(reserva * 6.96).toStringAsFixed(2)})'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Saldo a financiar (95%)', '\$${financiado.toStringAsFixed(2)} USD\n(Bs. ${(financiado * 6.96).toStringAsFixed(2)})'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Cuota mensual ($_selectedMonths cuotas)',
                        '\$${cuotaMensual.toStringAsFixed(2)} USD/mes\n(Bs. ${(cuotaMensual * 6.96).toStringAsFixed(2)}/mes)',
                        isBold: true,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _submittingPlan
                    ? null
                    : () async {
                        setState(() => _submittingPlan = true);
                        try {
                          await context.read<UserProvider>().comenzarProyectoConPlan(
                                _selectedPlan,
                                _selectedPlan == 'directo' ? 1 : _selectedMonths,
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Plan configurado y proyecto iniciado con éxito!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al iniciar el plan: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _submittingPlan = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submittingPlan
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedPlan == 'directo' ? 'Confirmar e Iniciar Proyecto' : 'Pagar Reserva e Iniciar Proyecto',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Caso D: Proyecto con plan de pagos establecido (Mostrar listado de cuotas)
    final double totalPaid = userProvider.montoPagadoReal;
    final double totalPending = userProvider.montoPendienteReal;
    final double budget = userProvider.budgetTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de tus Pagos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<UserProvider>().cargarProyectoYPagos(),
          )
        ],
      ),
      body: Column(
        children: [
          // Selector de proyecto si tiene más de uno
          if (userProvider.misProyectosReales.length > 1) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
              child: Container(
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
            ),
          ],
          // PANEL SUPERIOR: Resumen de pagos
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estado del Financiamiento:',
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: totalPending <= 0
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        totalPending <= 0 ? 'PAGADO COMPLETO' : 'PAGOS PENDIENTES',
                        style: TextStyle(
                          color: totalPending <= 0 ? Colors.green : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        'Monto Pagado',
                        '\$${totalPaid.toStringAsFixed(2)} USD\n(Bs. ${(totalPaid * 6.96).toStringAsFixed(2)})',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryBox(
                        'Saldo Pendiente',
                        '\$${totalPending.toStringAsFixed(2)} USD\n(Bs. ${(totalPending * 6.96).toStringAsFixed(2)})',
                        totalPending <= 0 ? Colors.grey : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Costo Total del Proyecto', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '\$${budget.toStringAsFixed(2)} USD\n(Bs. ${(budget * 6.96).toStringAsFixed(2)})',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // CRONOGRAMA DE CUOTAS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Cronograma de Pagos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  Expanded(
                    child: listado.isEmpty
                        ? const Center(
                            child: Text('No hay cuotas programadas para este proyecto.'),
                          )
                        : ListView.builder(
                            itemCount: listado.length,
                            itemBuilder: (context, index) {
                              final p = listado[index];
                              final String estado = p['estado'] ?? 'Pendiente';
                              final bool isPaid = estado == 'Completado' || estado == 'Pagado' || estado == 'Aprobado';
                              final double montoCuota = double.tryParse(p['monto']?.toString() ?? '') ?? 0.0;
                              
                              return _buildPaymentItem(
                                idPago: p['id_pago'],
                                title: p['metodo_pago'] ?? 'Cuota del Proyecto',
                                date: p['fecha'] != null
                                    ? p['fecha'].toString().substring(0, 10)
                                    : 'Pendiente',
                                amount: '\$${montoCuota.toStringAsFixed(2)} USD\n(Bs. ${(montoCuota * 6.96).toStringAsFixed(2)})',
                                isPaid: isPaid,
                                onPay: () async {
                                  setState(() => _processingPayment = true);
                                  try {
                                    await context.read<UserProvider>().pagarCuota(p['id_pago']);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Pago de "${p['metodo_pago']}" procesado con éxito!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error al procesar el pago: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _processingPayment = false);
                                    }
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? Colors.green
                  : (isActive ? Colors.amber : Colors.grey.shade300),
            ),
            child: Icon(
              isDone
                  ? Icons.check
                  : (isActive ? Icons.sync : Icons.lock_outline),
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDone || isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoQR(BuildContext context, int idPago, String cuotaNombre) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Map<String, dynamic>? qrData;
        String? errorMsg;
        bool cargando = true;
        bool confirmando = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (cargando && errorMsg == null && qrData == null) {
              context.read<UserProvider>().generarQrPago(idPago).then((data) {
                setDialogState(() {
                  qrData = data;
                  cargando = false;
                });
              }).catchError((err) {
                setDialogState(() {
                  errorMsg = err.toString();
                  cargando = false;
                });
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pago Rápido QR - $cuotaNombre',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cargando) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Generando Código QR...', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 40),
                  ] else if (errorMsg != null) ...[
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text(errorMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ] else if (qrData != null) ...[
                    const Text(
                      'Escanea el código QR desde tu banca móvil para pagar al instante.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.network(
                        qrData!['qr_url'],
                        width: 200,
                        height: 200,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(child: Text('Error al cargar QR')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildModalDetailRow('Banco:', qrData!['banco']),
                          const SizedBox(height: 6),
                          _buildModalDetailRow('Cuenta Destino:', qrData!['cuenta']),
                          const SizedBox(height: 6),
                          _buildModalDetailRow('Monto:', 'Bs. ${qrData!['monto']}'),
                          const SizedBox(height: 6),
                          _buildModalDetailRow('Concepto:', qrData!['concepto']),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (qrData != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: confirmando
                          ? null
                          : () async {
                              setDialogState(() => confirmando = true);
                              try {
                                await context.read<UserProvider>().confirmarQrPago(idPago);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('¡Transferencia realizada con éxito! Pago registrado.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => confirmando = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al confirmar pago: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: confirmando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(confirmando ? 'Procesando...' : 'Confirmar Transferencia Bancaria (Simulada)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem({
    required int idPago,
    required String title,
    required String date,
    required String amount,
    required bool isPaid,
    required VoidCallback onPay,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? Colors.green.shade100 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
              color: isPaid ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaid ? 'Pagado el: $date' : 'Vence: $date',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              isPaid
                  ? const Text(
                      'PAGADO',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: _processingPayment ? null : onPay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Pagar', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: _processingPayment
                                ? null
                                : () => _mostrarDialogoQR(context, idPago, title),
                            icon: const Icon(Icons.qr_code_2, size: 14, color: Colors.white),
                            label: const Text('QR', style: TextStyle(fontSize: 11, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          )
        ],
      ),
    );
  }
}
