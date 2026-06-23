import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:app_constructora/core/constants/api_constants.dart';
import 'package:app_constructora/core/config/environment.dart';
import '../services/auth_service.dart';
import '../services/cotizacion_service.dart';
import '../services/notification_service.dart';

class UserProvider extends ChangeNotifier {
  bool _hasActiveProject = false;
  bool _pendingReservation = false;
  double _globalProgress = 15.0;
  double _budgetTotal = 185000.0;
  String _userName = 'Carlos Martínez';
  String _userEmail = 'carlos.m@example.com';
  String? _profilePhotoPath;
  bool _isLoading = false;
  List<dynamic> _listaEmpresas = [];
  List<dynamic> get listaEmpresas => _listaEmpresas;
  final AuthService _authService = AuthService();
  final CotizacionService _cotizacionService = CotizacionService();

  UserProvider() {
    loadProfilePhoto();
  }

  int? _idCotizacionCreada;
  bool _tieneProyectoReal = false;
  Map<String, dynamic>? _proyectoRealData;
  Map<String, dynamic>? _cotizacionProyectoReal;
  List<dynamic> _pagosReales = [];
  double _montoPagadoReal = 0.0;
  double _montoPendienteReal = 0.0;
  int? _idProyectoSeleccionado;
  List<dynamic> _misProyectosReales = [];
  List<dynamic> _documentosProyecto = [];
  List<dynamic> get documentosProyecto => _documentosProyecto;
  List<String> _fotosProyecto = [];
  List<String> get fotosProyecto => _fotosProyecto;

  bool get hasActiveProject => _hasActiveProject;
  int? get idProyectoSeleccionado => _idProyectoSeleccionado;
  List<dynamic> get misProyectosReales => _misProyectosReales;
  bool get pendingReservation => _pendingReservation;
  double get globalProgress => _globalProgress;
  double get budgetTotal => _budgetTotal;
  String get userName => _userName;
  String get userEmail => _userEmail;
  bool get isLoading => _isLoading;
  String? get profilePhotoPath => _profilePhotoPath;

  int? get idCotizacionCreada => _idCotizacionCreada;
  bool get tieneProyectoReal => _tieneProyectoReal;
  Map<String, dynamic>? get proyectoRealData => _proyectoRealData;
  Map<String, dynamic>? get cotizacionProyectoReal => _cotizacionProyectoReal;
  List<dynamic> get pagosReales => _pagosReales;
  double get montoPagadoReal => _montoPagadoReal;
  double get montoPendienteReal => _montoPendienteReal;

  // Actualizar datos del usuario
  void setUserData(String name, String email) {
    if (name.isNotEmpty) _userName = name;
    if (email.isNotEmpty) _userEmail = email;
    notifyListeners();
  }

  // Actualizar foto de perfil
  Future<void> updateProfilePhotoPath(String path) async {
    _profilePhotoPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_path', path);
  }

  // Cargar foto de perfil al iniciar
  Future<void> loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    _profilePhotoPath = prefs.getString('profile_photo_path');
    notifyListeners();
  }

  // Registro con API real (Actualizado)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String telefono,
    required String direccion,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.register(
        nombreCompleto: name,
        email: email,
        password: password,
        telefono: telefono,
        direccion: direccion,
      );
      
      _userName = response['user']?['name'] ?? name;
      _userEmail = response['user']?['email'] ?? email;
      _hasActiveProject = false;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Login con API real
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);
      
      // Suponiendo que la API devuelve un objeto con 'name', 'email', etc.
      _userName = response['user']['name'] ?? 'Usuario';
      _userEmail = response['user']['email'] ?? email;
      _hasActiveProject = response['user']['hasActiveProject'] ?? false;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow; // Lanzar para que la UI pueda mostrar el error
    }
  }

  // Login global en central
  Future<Map<String, dynamic>> loginGlobal(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.loginGlobal(email, password);
      _listaEmpresas = response['empresas'] ?? [];
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Vincular a la empresa seleccionada
  Future<bool> seleccionarEmpresa(String email, int idEmpresa) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.seleccionarEmpresa(email, idEmpresa);
      _userName = response['user']['name'] ?? 'Usuario';
      _userEmail = response['user']['email'] ?? email;
      _hasActiveProject = response['user']['hasActiveProject'] ?? false;

      // Cargar datos locales de proyecto correspondientes a la empresa seleccionada
      await cargarProyectoYPagos();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Login como usuario existente (Simulado/Mock actualizado)
  Future<void> loginAsActiveUser() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // Simular latencia

    _hasActiveProject = true;
    _pendingReservation = false;
    _globalProgress = 30.0;
    
    _isLoading = false;
    notifyListeners();
  }

  // Login como usuario nuevo (Simulado/Mock actualizado)
  Future<void> loginAsNewUser() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // Simular latencia

    _hasActiveProject = false;
    _pendingReservation = false;
    _globalProgress = 0.0;
    
    _isLoading = false;
    notifyListeners();
  }

  // Aceptar presupuesto manual
  void acceptBudget(double totalAcordado) {
    _budgetTotal = totalAcordado;
    _pendingReservation = true;
    notifyListeners();
  }

  // Guardar cotización en la base de datos real
  Future<void> saveCotizacion({
    String? nombre,
    required String ubicacion,
    required int m2Terreno,
    required int m2Construir,
    required int habitaciones,
    required int banos,
    required String calidadMateriales,
    required List<String> ambientes,
    required String adicionales,
    required double costoEstimado,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cotizacion = CotizacionModel(
        nombre: nombre,
        ubicacion: ubicacion,
        m2Terreno: m2Terreno,
        m2Construir: m2Construir,
        habitaciones: habitaciones,
        banos: banos,
        calidadMateriales: calidadMateriales,
        ambientes: ambientes,
        adicionales: adicionales.isNotEmpty ? adicionales : null,
        costoEstimado: costoEstimado,
        estado: 'Pendiente',
      );

      final saved = await _cotizacionService.guardarCotizacion(cotizacion);
      _idCotizacionCreada = saved.idCotizacion;
      _budgetTotal = costoEstimado;
      _pendingReservation = false;

      // Solicitar el proyecto automáticamente al enviar
      if (_idCotizacionCreada != null) {
        await solicitarProyecto(_idCotizacionCreada!);
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> solicitarProyecto(int idCotizacion) async {
    _isLoading = true;
    notifyListeners();
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/proyectos/solicitar');
      final prefs = await SharedPreferences.getInstance();
      final int idUsuario = prefs.getInt('id_usuario') ?? 1;
      final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
        body: json.encode({
          'id_cotizacion': idCotizacion,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _idCotizacionCreada = null;
        _pendingReservation = false;
        await cargarProyectoYPagos();
      } else {
        final decoded = json.decode(response.body);
        throw Exception(decoded['detail'] ?? 'Error al solicitar el proyecto.');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verificarCotizacionPendiente() async {
    try {
      final cotizaciones = await _cotizacionService.obtenerMisCotizaciones();
      final pendientes = cotizaciones.where((c) => c.estado == 'Pendiente').toList();
      if (pendientes.isNotEmpty) {
        _idCotizacionCreada = pendientes.first.idCotizacion;
        _budgetTotal = pendientes.first.costoEstimado;
        if (_idCotizacionCreada != null) {
          await solicitarProyecto(_idCotizacionCreada!);
        }
      }
    } catch (e) {
      print('Error al verificar cotizaciones pendientes: $e');
    }
  }

  Future<void> cargarProyectoYPagos() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final int idUsuario = prefs.getInt('id_usuario') ?? 1;
      final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);

      // Iniciar la escucha de notificaciones SSE en tiempo real
      NotificationService().startListening(idUsuario);

      // 1. Obtener listado de todos los proyectos del cliente
      final listUrl = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/cliente/proyectos');
      final listResponse = await http.get(
        listUrl,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
      );

      if (listResponse.statusCode == 200) {
        final List decodedList = json.decode(listResponse.body);
        _misProyectosReales = decodedList;

        if (_misProyectosReales.isNotEmpty) {
          final hasSelected = _misProyectosReales.any((p) => p['id_proyecto'] == _idProyectoSeleccionado);
          if (_idProyectoSeleccionado == null || !hasSelected) {
            _idProyectoSeleccionado = _misProyectosReales.first['id_proyecto'];
          }
        } else {
          _idProyectoSeleccionado = null;
        }
      }

      if (_idProyectoSeleccionado == null) {
        _tieneProyectoReal = false;
        _hasActiveProject = false;
        _proyectoRealData = null;
        _cotizacionProyectoReal = null;
        _pagosReales = [];
        _montoPagadoReal = 0.0;
        _montoPendienteReal = 0.0;
        return;
      }

      // 2. Obtener detalles del proyecto seleccionado
      final detailsUrl = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/cliente/proyectos/$_idProyectoSeleccionado');
      final response = await http.get(
        detailsUrl,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _tieneProyectoReal = true;
        _hasActiveProject = true;
        _proyectoRealData = decoded['proyecto'];
        _cotizacionProyectoReal = decoded['cotizacion'];
        _pagosReales = decoded['pagos'] ?? [];
        _montoPagadoReal = double.tryParse(decoded['total_pagado']?.toString() ?? '') ?? 0.0;
        _montoPendienteReal = double.tryParse(decoded['total_pendiente']?.toString() ?? '') ?? 0.0;
        _budgetTotal = double.tryParse(decoded['total_estimado']?.toString() ?? '') ?? (_montoPagadoReal + _montoPendienteReal);
        _documentosProyecto = decoded['documentos'] ?? [];
        _fotosProyecto = List<String>.from(decoded['fotos'] ?? []);

        if (_proyectoRealData != null) {
          final String prgStr = _proyectoRealData!['porcentaje_avance']?.toString() ?? '';
          final double? prg = double.tryParse(prgStr);
          if (prg != null) {
            _globalProgress = prg;
          } else {
            final String est = _proyectoRealData!['estado'] ?? 'En planificación';
            if (est == 'Finalizado') {
              _globalProgress = 100.0;
            } else if (est == 'En planificación' || est == 'Pendiente') {
              _globalProgress = 0.0;
            }
          }
        }
      }
    } catch (e) {
      print('Error al cargar proyecto y pagos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> seleccionarProyecto(int idProyecto) async {
    _idProyectoSeleccionado = idProyecto;
    notifyListeners();
    await cargarProyectoYPagos();
  }

  Future<void> comenzarProyectoConPlan(String tipoPlan, int cantidadCuotas) async {
    if (_idProyectoSeleccionado == null) {
      throw Exception('No hay ningún proyecto activo o seleccionado.');
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/proyectos/$_idProyectoSeleccionado/establecer-plan');
      final prefs = await SharedPreferences.getInstance();
      final int idUsuario = prefs.getInt('id_usuario') ?? 1;
      final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
        body: json.encode({
          'tipo_plan': tipoPlan,
          'cantidad_cuotas': cantidadCuotas,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingReservation = false;
        await cargarProyectoYPagos();
      } else {
        final decoded = json.decode(response.body);
        throw Exception(decoded['detail'] ?? 'Error al establecer el plan de pagos.');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pagarCuota(int idPago) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/pagos/$idPago/pagar');
      final prefs = await SharedPreferences.getInstance();
      final int idUsuario = prefs.getInt('id_usuario') ?? 1;
      final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await cargarProyectoYPagos();
      } else {
        final decoded = json.decode(response.body);
        throw Exception(decoded['detail'] ?? 'Error al procesar el pago de la cuota.');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Simular pago de reserva exitoso
  void payReservation() {
    _pendingReservation = false;
    _hasActiveProject = true;
    _globalProgress = 0.0; // Inicia la obra con 0% de progreso lógicamente
    notifyListeners();
  }

  // Setter de progreso dinámico para reflejarse en Home y Mi Obra
  void setProgress(double val) {
    _globalProgress = val;
    notifyListeners();
  }

  // Cambiar la contraseña del usuario actual
  Future<void> cambiarContrasena(String contrasenaActual, String nuevaContrasena) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? idEmpresa = prefs.getInt('id_empresa');

      await _authService.cambiarContrasena(
        _userEmail,
        contrasenaActual,
        nuevaContrasena,
        idEmpresa,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Notificar al backend y borrar SharedPreferences local
      await _authService.logout();
    } catch (e) {
      print("Error al cerrar sesión: $e");
    } finally {
      // 2. Limpiar el estado de las variables locales en memoria de la App
      _hasActiveProject = false;
      _pendingReservation = false;
      _globalProgress = 15.0; // Resetear a valor inicial
      _userName = 'Usuario Desconectado';
      _userEmail = '';
      _proyectoRealData = null;
      _cotizacionProyectoReal = null;
      _documentosProyecto = [];
      _fotosProyecto = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> subirArchivoProyecto(String filePath, String tipoAdjunto) async {
    if (_idProyectoSeleccionado == null) return;
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/documentos/proyecto/$_idProyectoSeleccionado/adjuntar');
      final prefs = await SharedPreferences.getInstance();
      final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);
      final int idUsuario = prefs.getInt('id_usuario') ?? 1;

      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'X-Empresa-Id': idEmpresa.toString(),
        'X-Usuario-Id': idUsuario.toString(),
      });

      request.fields['tipo_adjunto'] = tipoAdjunto;
      request.files.add(await http.MultipartFile.fromPath('archivo', filePath));

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Archivo subido con éxito: $filePath");
      } else {
        final respStr = await response.stream.bytesToString();
        throw Exception("Error al subir archivo: $respStr");
      }
    } catch (e) {
      print("Error en subirArchivoProyecto: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generarQrPago(int idPago) async {
    final prefs = await SharedPreferences.getInstance();
    final int idUsuario = prefs.getInt('id_usuario') ?? 1;
    final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);
    
    final url = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/qr/$idPago/generar-qr');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Empresa-Id': idEmpresa.toString(),
        'X-Usuario-Id': idUsuario.toString(),
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Error al generar QR');
    }
  }

  Future<void> confirmarQrPago(int idPago) async {
    final prefs = await SharedPreferences.getInstance();
    final int idUsuario = prefs.getInt('id_usuario') ?? 1;
    final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);
    
    final url = Uri.parse('${ApiConstants.baseUrl}/casos-uso/hu33/qr/$idPago/confirmar-qr');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Empresa-Id': idEmpresa.toString(),
        'X-Usuario-Id': idUsuario.toString(),
      },
    );
    
    if (response.statusCode == 200) {
      await cargarProyectoYPagos();
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Error al confirmar pago QR');
    }
  }
}
