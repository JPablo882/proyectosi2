import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_constructora/theme/app_theme.dart';
import 'package:app_constructora/services/ia_service.dart';
import 'package:app_constructora/screens/budget_screen.dart';

class VoicePromptScreen extends StatefulWidget {
  const VoicePromptScreen({super.key});

  @override
  State<VoicePromptScreen> createState() => _VoicePromptScreenState();
}

class _VoicePromptScreenState extends State<VoicePromptScreen>
    with TickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  late FlutterTts _flutterTts;
  final IaService _iaService = IaService();

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = 'Toca la esfera para empezar a hablar';
  String _transcription = '';

  // Controladores de Animación
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  // Variables para control de navegación dinámico por voz
  IaCotizacionResult? _cachedResult;
  bool _shouldNavigateAfterSpeech = false;
  bool _hasNavigated = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _initTts();

    // Animación de flotar (idle)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Animación de pulso (grabando)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Animación de rotación lenta
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Saludo inicial por voz al cargar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak(
        '¡Hola! Estoy lista para escucharte. Cuéntame con todo el detalle que quieras cómo te imaginas la casa de tus sueños.',
      );
    });
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setSpeechRate(0.5); // Velocidad natural de lectura
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Navegar automáticamente SOLO cuando la síntesis de voz del resumen finalice
    _flutterTts.setCompletionHandler(() {
      if (_shouldNavigateAfterSpeech && _cachedResult != null) {
        _navigate(_cachedResult!);
      }
    });
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error al reproducir voz: $e');
    }
  }

  void _navigate(IaCotizacionResult result) {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      _flutterTts.stop();
      _navigationTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BudgetScreen(initialData: result),
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _flutterTts.stop();
    _navigationTimer?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _handleSphereTap() async {
    if (_isProcessing) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Detener cualquier voz activa antes de grabar
      await _flutterTts.stop();

      // Solicitar permisos de micrófono
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusText = 'Permiso de micrófono denegado';
        });
        return;
      }

      // Iniciar grabación en archivo temporal (.m4a)
      final tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/grabacion_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() {
        _isRecording = true;
        _statusText = 'Escuchándote... Toca la esfera al terminar';
        _transcription = '';
      });

      _pulseController.repeat(reverse: true);

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusText = 'Error al iniciar la grabación';
      });
      _pulseController.stop();
      print('Error al grabar: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _pulseController.stop();
      _pulseController.animateTo(0.0, duration: const Duration(milliseconds: 200));

      if (path == null) {
        setState(() {
          _isRecording = false;
          _statusText = 'No se guardó el audio';
        });
        return;
      }

      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusText = 'Procesando tus deseos... 🪄';
      });

      // La IA notifica que está procesando por voz
      await _speak('¡Entendido! Estoy procesando tus especificaciones con la inteligencia artificial. Dame un momento.');

      // Enviar audio al backend a través de IaService
      final result = await _iaService.enviarAudioCotizacion(path);

      setState(() {
        _transcription = result.transcripcion;
        _statusText = '¡Todo listo! Redirigiendo a tu cotización';
      });

      // Crear síntesis de voz de resumen estructurado
      String materialText = result.calidadMateriales;
      String m2Text = result.m2Construir > 0 ? '${result.m2Construir} metros cuadrados' : '';
      String roomsText = result.habitaciones == 1 ? 'una habitación' : '${result.habitaciones} habitaciones';
      String banosText = result.banos == 1 ? 'un baño' : '${result.banos} baños';
      String locText = result.ubicacion.isNotEmpty ? 'en ${result.ubicacion}' : '';

      String speechSummary = '¡Hecho! He preparado tu presupuesto $locText ';
      if (m2Text.isNotEmpty) speechSummary += 'con $m2Text de construcción, ';
      speechSummary += 'distribuidos en $roomsText y $banosText, utilizando acabados $materialText. ';
      
      if (result.adicionales.isNotEmpty) {
        speechSummary += 'Además, añadí a los detalles adicionales tu interés en ${result.adicionales}.';
      }

      // Almacenar el resultado y levantar la bandera para la navegación
      _cachedResult = result;
      _shouldNavigateAfterSpeech = true;

      // Reproducir síntesis de voz (al terminar llamará al setCompletionHandler)
      await _speak(speechSummary);

      // Fallback absoluto por seguridad: si la voz se traba o no completa en 15 segundos, redirige de todos modos
      _navigationTimer = Timer(const Duration(seconds: 15), () {
        _navigate(result);
      });

    } catch (e) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusText = 'Vuelve a intentarlo: $e';
      });
      _speak('Ocurrió un pequeño inconveniente. Por favor, vuelve a intentarlo.');
      print('Error al procesar audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco impecable como pidió el usuario
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cuéntale a la IA',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'cómo quieres la casa de tus sueños',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 16,
                      ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),

                // Esfera de IA con CustomPainter Animado
                Center(
                  child: GestureDetector(
                    onTap: _handleSphereTap,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _floatController,
                        _pulseController,
                        _rotateController
                      ]),
                      builder: (context, child) {
                        // Desplazamiento vertical flotante suave (idle)
                        final floatValue = math.sin(_floatController.value * math.pi * 2) * 10.0;
                        // Escalado por pulsación de voz (recording)
                        final pulseScale = 1.0 + (_pulseController.value * 0.12);

                        return Transform.translate(
                          offset: Offset(0, floatValue),
                          child: Transform.scale(
                            scale: pulseScale,
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF06B6D4).withOpacity(_isRecording ? 0.35 : 0.12),
                                    blurRadius: _isRecording ? 45 : 20,
                                    spreadRadius: _isRecording ? 8 : 1,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(_isRecording ? 0.25 : 0.08),
                                    blurRadius: _isRecording ? 50 : 30,
                                    spreadRadius: _isRecording ? 4 : 0,
                                  )
                                ],
                              ),
                              child: CustomPaint(
                                painter: IaSpherePainter(
                                  rotation: _rotateController.value,
                                  pulse: _pulseController.value,
                                  isRecording: _isRecording,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Estado de Procesamiento / Cargando
                if (_isProcessing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),

                // Texto descriptivo del estado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: _isRecording
                          ? const Color(0xFF10B981)
                          : (_isProcessing ? const Color(0xFF06B6D4) : const Color(0xFF334155)),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Transcripción del audio (Feedback visual)
                if (_transcription.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Fondo gris muy claro para contrastar sobre blanco
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Lo que entendimos:',
                          style: TextStyle(
                            color: Color(0xFF06B6D4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"$_transcription"',
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pintor de Esfera 3D fluida y glowing
class IaSpherePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final bool isRecording;

  IaSpherePainter({
    required this.rotation,
    required this.pulse,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()..isAntiAlias = true;

    // 1. Capa de Sombra Suave (Para efecto flotante 3D sobre fondo blanco)
    paint.color = Colors.black.withOpacity(0.08);
    canvas.drawCircle(Offset(center.dx, center.dy + 8), radius * 0.95, paint);

    // 2. Capa de Fondo - Esfera base sólida translúcida muy suave
    paint.shader = const RadialGradient(
      center: Alignment(-0.2, -0.3),
      radius: 0.95,
      colors: [
        Color(0xFFF8FAFC),
        Color(0xFFE2E8F0),
      ],
      stops: [0.1, 0.9],
    ).createShader(rect);
    canvas.drawCircle(center, radius * 0.98, paint);

    // 3. Capa Fluida Azul y Verde (Brillo interior dinámico)
    final double angle = rotation * math.pi * 2;
    final Offset tealOffset = Offset(
      center.dx + math.cos(angle) * (radius * 0.25),
      center.dy + math.sin(angle) * (radius * 0.25),
    );
    final Offset greenOffset = Offset(
      center.dx + math.cos(angle + math.pi) * (radius * 0.3),
      center.dy + math.sin(angle + math.pi) * (radius * 0.3),
    );

    // Gradiente Cyan / Azul
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF06B6D4).withOpacity(isRecording ? 0.75 : 0.60),
        const Color(0xFF3B82F6).withOpacity(0.0),
      ],
      stops: const [0.0, 0.8],
    ).createShader(Rect.fromCircle(center: tealOffset, radius: radius * 0.85));
    canvas.drawCircle(center, radius * 0.95, paint);

    // Gradiente Verde / Esmeralda
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF10B981).withOpacity(isRecording ? 0.70 : 0.50),
        const Color(0xFF047857).withOpacity(0.0),
      ],
      stops: const [0.0, 0.85],
    ).createShader(Rect.fromCircle(center: greenOffset, radius: radius * 0.8));
    canvas.drawCircle(center, radius * 0.95, paint);

    // 4. Destellos 3D (Brillo especular superior de cristal)
    final Offset specCenter = Offset(center.dx - radius * 0.28, center.dy - radius * 0.28);
    paint.shader = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.85),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: specCenter, radius: radius * 0.4));
    canvas.drawCircle(center, radius * 0.95, paint);

    // Destello de borde inferior secundario (Reflejo de luz ambiente en cristal)
    final Offset bottomSpecCenter = Offset(center.dx + radius * 0.3, center.dy + radius * 0.3);
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF06B6D4).withOpacity(0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: bottomSpecCenter, radius: radius * 0.45));
    canvas.drawCircle(center, radius * 0.95, paint);
  }

  @override
  bool shouldRepaint(covariant IaSpherePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isRecording != isRecording;
  }
}
