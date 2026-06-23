import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:app_constructora/core/constants/api_constants.dart';
import 'package:app_constructora/core/config/environment.dart';

class CotizacionModel {
  final int? idCotizacion;
  final int? idUsuarios;
  final String? nombre;
  final String ubicacion;
  final int m2Terreno;
  final int m2Construir;
  final int habitaciones;
  final int banos;
  final String calidadMateriales;
  final List<String> ambientes;
  final String? adicionales;
  final double costoEstimado;
  final String? fecha;
  final String estado;

  CotizacionModel({
    this.idCotizacion,
    this.idUsuarios,
    this.nombre,
    required this.ubicacion,
    required this.m2Terreno,
    required this.m2Construir,
    required this.habitaciones,
    required this.banos,
    required this.calidadMateriales,
    required this.ambientes,
    this.adicionales,
    required this.costoEstimado,
    this.fecha,
    required this.estado,
  });

  factory CotizacionModel.fromJson(Map<String, dynamic> json) {
    return CotizacionModel(
      idCotizacion: json['id_cotizacion'],
      idUsuarios: json['id_usuarios'],
      nombre: json['nombre'],
      ubicacion: json['ubicacion'] ?? '',
      m2Terreno: json['m2_terreno'] ?? 0,
      m2Construir: json['m2_construir'] ?? 0,
      habitaciones: json['habitaciones'] ?? 1,
      banos: json['banos'] ?? 1,
      calidadMateriales: json['calidad_materiales'] ?? 'Estándar',
      ambientes: List<String>.from(json['ambientes'] ?? []),
      adicionales: json['adicionales'],
      costoEstimado: (json['costo_estimado'] is num)
          ? (json['costo_estimado'] as num).toDouble()
          : (json['costo_estimado'] is String)
              ? (double.tryParse(json['costo_estimado'] as String) ?? 0.0)
              : 0.0,
      fecha: json['fecha'],
      estado: json['estado'] ?? 'Pendiente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'ubicacion': ubicacion,
      'm2_terreno': m2Terreno,
      'm2_construir': m2Construir,
      'habitaciones': habitaciones,
      'banos': banos,
      'calidad_materiales': calidadMateriales,
      'ambientes': ambientes,
      'adicionales': adicionales,
      'costo_estimado': costoEstimado,
    };
  }
}

class CotizacionService {
  Future<CotizacionModel> guardarCotizacion(CotizacionModel cotizacion) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cotizaciones}');
    
    final prefs = await SharedPreferences.getInstance();
    final int idUsuario = prefs.getInt('id_usuario') ?? 1; // Default fallback to user 1
    final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
        body: json.encode(cotizacion.toJson()),
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CotizacionModel.fromJson(decoded);
      } else {
        throw Exception(decoded['detail'] ?? 'Error al guardar la cotización');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  Future<List<CotizacionModel>> obtenerMisCotizaciones() async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.misCotizaciones}');
    
    final prefs = await SharedPreferences.getInstance();
    final int idUsuario = prefs.getInt('id_usuario') ?? 1;
    final int idEmpresa = prefs.getInt('id_empresa') ?? int.parse(Environment.empresaId);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Empresa-Id': idEmpresa.toString(),
          'X-Usuario-Id': idUsuario.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List decoded = json.decode(response.body);
        return decoded.map((item) => CotizacionModel.fromJson(item)).toList();
      } else {
        final decoded = json.decode(response.body);
        throw Exception(decoded['detail'] ?? 'Error al obtener las cotizaciones');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }
}
