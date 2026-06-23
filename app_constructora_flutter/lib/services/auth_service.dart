import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:app_constructora/core/constants/api_constants.dart';
import 'package:app_constructora/core/config/environment.dart';

class AuthService {
  // Login con la API real de FastAPI y la BD local
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': Environment.empresaId, // Leído dinámicamente de la configuración
        },
        body: json.encode({
          'identificador': email,
          'contrasena': password,
        }),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        // Guardar la sesión localmente en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('id_usuario', decoded['id_usuario']);
        await prefs.setInt('id_empresa', decoded['id_empresa']);
        await prefs.setString('usuario', decoded['usuario']);
        await prefs.setString('email', decoded['email']);
        await prefs.setString('rol', decoded['rol']);
        await prefs.setString('nombres', decoded['nombres']);
        await prefs.setString('apellido', decoded['apellido']);

        // Estructura que espera el UserProvider
        return {
          'status': 'success',
          'user': {
            'name': '${decoded['nombres']} ${decoded['apellido']}'.trim(),
            'email': decoded['email'],
            'hasActiveProject': decoded['has_active_project'] ?? false,
          },
        };
      } else {
        // Extraer el mensaje de error del backend
        final detail = decoded['detail'];
        String errorMsg = 'Error al iniciar sesión.';
        if (detail is String) {
          errorMsg = detail;
        } else if (detail is Map && detail.containsKey('message')) {
          errorMsg = detail['message'];
        } else if (decoded.containsKey('mensaje')) {
          errorMsg = decoded['mensaje'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Login global en la BD central para obtener la lista de empresas
  Future<Map<String, dynamic>> loginGlobal(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginGlobal}');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'contrasena': password,
        }),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        return decoded; // {mensaje, email, nombres, apellido, empresas}
      } else {
        final detail = decoded['detail'];
        String errorMsg = 'Error al iniciar sesión global.';
        if (detail is String) {
          errorMsg = detail;
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Vincular y obtener sesión para la empresa seleccionada
  Future<Map<String, dynamic>> seleccionarEmpresa(String email, int idEmpresa) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.seleccionarEmpresa}');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'id_empresa': idEmpresa,
        }),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        // Guardar la sesión localmente en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('id_usuario', decoded['id_usuario']);
        await prefs.setInt('id_empresa', decoded['id_empresa']);
        await prefs.setString('usuario', decoded['usuario']);
        await prefs.setString('email', decoded['email']);
        await prefs.setString('rol', decoded['rol']);
        await prefs.setString('nombres', decoded['nombres']);
        await prefs.setString('apellido', decoded['apellido']);

        return {
          'status': 'success',
          'user': {
            'name': '${decoded['nombres']} ${decoded['apellido']}'.trim(),
            'email': decoded['email'],
            'hasActiveProject': decoded['has_active_project'] ?? false,
          },
        };
      } else {
        final detail = decoded['detail'] ?? 'Error al seleccionar la empresa.';
        throw Exception(detail);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Registro global en la BD central sin header de empresa
  Future<Map<String, dynamic>> register({
    required String nombreCompleto,
    required String telefono,
    required String direccion,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerGlobal}');
    
    // Separar nombre completo en nombres y apellidos
    List<String> nameParts = nombreCompleto.trim().split(' ');
    String nombres = nameParts.first;
    String apellido = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    if (apellido.isEmpty) {
      apellido = ' '; // Evitar cadenas vacías para Pydantic/SQLModel
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombres': nombres,
          'apellido': apellido,
          'email': email,
          'contrasena': password,
          'telefono': telefono,
          'direccion': direccion,
        }),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'success',
          'user': {
            'name': nombreCompleto,
            'email': email,
            'telefono': telefono,
            'direccion': direccion,
            'hasActiveProject': false,
          },
        };
      } else {
        final detail = decoded['detail'];
        String errorMsg = 'Error al registrar la cuenta.';
        if (detail is String) {
          errorMsg = detail;
        } else if (detail is Map && detail.containsKey('message')) {
          errorMsg = detail['message'];
        } else if (decoded.containsKey('mensaje')) {
          errorMsg = decoded['mensaje'];
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Cambiar contraseña global y localmente
  Future<void> cambiarContrasena(
      String email, String contrasenaActual, String nuevaContrasena, int? idEmpresa) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cambiarContrasena}');
    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      if (idEmpresa != null) {
        headers['X-Empresa-Id'] = idEmpresa.toString();
      }

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'email': email,
          'contrasena_actual': contrasenaActual,
          'nueva_contrasena': nuevaContrasena,
        }),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode != 200) {
        final detail = decoded['detail'] ?? 'Error al cambiar la contraseña.';
        throw Exception(detail);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Método para cerrar sesión notificando al backend y borrando caché local
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final int? idUsuario = prefs.getInt('id_usuario');
    final int? idEmpresa = prefs.getInt('id_empresa');

    if (idUsuario != null && idEmpresa != null) {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}');
      try {
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Empresa-Id': idEmpresa.toString(),
            'X-Usuario-Id': idUsuario.toString(),
          },
        );
      } catch (e) {
        // En caso de que no haya red, informamos en consola pero permitimos continuar con el borrado local
        print("No se pudo notificar al backend del cierre de sesión: $e");
      }
    }

    // Limpiar claves locales guardadas durante el login
    await prefs.remove('id_usuario');
    await prefs.remove('id_empresa');
    await prefs.remove('usuario');
    await prefs.remove('email');
    await prefs.remove('rol');
    await prefs.remove('nombres');
    await prefs.remove('apellido');
  }
}
