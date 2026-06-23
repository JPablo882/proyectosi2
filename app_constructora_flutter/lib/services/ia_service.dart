import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_constructora/core/constants/api_constants.dart';

class IaCotizacionResult {
  final String transcripcion;
  final String ubicacion;
  final int m2Terreno;
  final int m2Construir;
  final int habitaciones;
  final int banos;
  final String calidadMateriales;
  final List<String> ambientes;
  final String adicionales;

  IaCotizacionResult({
    required this.transcripcion,
    required this.ubicacion,
    required this.m2Terreno,
    required this.m2Construir,
    required this.habitaciones,
    required this.banos,
    required this.calidadMateriales,
    required this.ambientes,
    required this.adicionales,
  });

  factory IaCotizacionResult.fromJson(Map<String, dynamic> json) {
    return IaCotizacionResult(
      transcripcion: json['transcripcion'] ?? '',
      ubicacion: json['ubicacion'] ?? '',
      m2Terreno: json['m2_terreno'] ?? 0,
      m2Construir: json['m2_construir'] ?? 0,
      habitaciones: json['habitaciones'] ?? 1,
      banos: json['banos'] ?? 1,
      calidadMateriales: json['calidad_materiales'] ?? 'Estándar',
      ambientes: List<String>.from(json['ambientes'] ?? []),
      adicionales: json['adicionales'] ?? '',
    );
  }
}

class IaService {
  Future<IaCotizacionResult> enviarAudioCotizacion(String filePath) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cotizarAudio}');
    
    try {
      final request = http.MultipartRequest('POST', url);
      
      // Adjuntar el archivo de audio
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          filePath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return IaCotizacionResult.fromJson(decoded);
      } else {
        String errorMsg = 'Error del servidor al procesar el audio.';
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded.containsKey('detail')) {
            errorMsg = decoded['detail'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }
}
