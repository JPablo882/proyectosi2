import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:app_constructora/core/constants/api_constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_constructora/providers/notification_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  http.Client? _sseClient;
  bool _shouldListen = false;
  int? _currentUserId;

  Future<void> init() async {
    if (_isInitialized) return;

    // Pedir permisos de notificaciones para Android 13+
    await Permission.notification.request();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
    _isInitialized = true;
    print("[NotificationService] Inicializado correctamente.");
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'constructora_channel_id',
      'Notificaciones de Obra',
      channelDescription: 'Alertas inmediatas de avances, pagos y cotizaciones',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  void startListening(int idUsuario) {
    if (_currentUserId == idUsuario && _shouldListen) {
      print("[NotificationService] Ya escuchando notificaciones para el usuario $idUsuario");
      return;
    }
    
    stopListening();
    _shouldListen = true;
    _currentUserId = idUsuario;
    _listenLoop(idUsuario);
  }

  void stopListening() {
    print("[NotificationService] Deteniendo escucha de notificaciones");
    _shouldListen = false;
    _sseClient?.close();
    _sseClient = null;
    _currentUserId = null;
  }

  Future<void> _listenLoop(int idUsuario) async {
    while (_shouldListen && _currentUserId == idUsuario) {
      _sseClient = http.Client();
      final url = Uri.parse('${ApiConstants.baseUrl}/notificaciones/stream/$idUsuario');
      print("[NotificationService] Conectando a stream de notificaciones SSE: $url");
      
      try {
        final request = http.Request("GET", url);
        request.headers["Accept"] = "text/event-stream";
        request.headers["Cache-Control"] = "no-cache";
        
        final response = await _sseClient!.send(request);
        
        if (response.statusCode == 200) {
          print("[NotificationService] Stream SSE abierto exitosamente.");
          // Escuchar el stream de texto línea por línea
          await for (final line in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
            
            if (!_shouldListen || _currentUserId != idUsuario) break;
            
            if (line.startsWith("data:")) {
              final dataStr = line.substring(5).trim();
              if (dataStr.isEmpty) continue;
              
              try {
                final data = jsonDecode(dataStr);
                if (data["type"] == "notification") {
                  final String title = data["title"] ?? "Notificación de Obra";
                  final String message = data["body"] ?? "";
                  
                  await showNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: title,
                    body: message,
                  );

                  // Guardar en el provider de la app
                  final date = DateTime.now().toString().substring(0, 16);
                  NotificationProvider().addNotification(title, message, date);
                }
              } catch (e) {
                print("[NotificationService] Error decodificando evento SSE: $e");
              }
            }
          }
        } else {
          print("[NotificationService] SSE falló con código de estado: ${response.statusCode}");
        }
      } catch (e) {
        print("[NotificationService] Error de conexión en el stream de notificaciones: $e");
      } finally {
        _sseClient?.close();
      }
      
      // Esperar 5 segundos antes de intentar reconectar
      if (_shouldListen && _currentUserId == idUsuario) {
        print("[NotificationService] Reintentando conexión SSE en 5 segundos...");
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }
}
