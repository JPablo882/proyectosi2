import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isNightMode = false;
  String? _lastImagePath;
  String _selectedMode = 'AI CAM';

  final List<String> _cameraModes = ['Vídeo', 'AI CAM', 'Belleza', 'Bokeh', 'Pano'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      } else {
        print("No se encontraron cámaras");
      }
    } catch (e) {
      print("Error al inicializar cámaras: $e");
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      // Establecer modo flash inicial
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Error al inicializar controlador de cámara: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      print("Error al configurar flash: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, photo.path);
      }
    } catch (e) {
      print("Error al tomar foto: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        Navigator.pop(context, pickedFile.path);
      }
    } catch (e) {
      print("Error al abrir galería: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la galería: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: _isFlashOn ? Colors.amber : Colors.white,
                      size: 24,
                    ),
                    onPressed: _toggleFlash,
                  ),
                  const Text(
                    'HDR A',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.aspect_ratio, color: Colors.white, size: 24),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.nightlight_round,
                      color: _isNightMode ? Colors.amber : Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNightMode = !_isNightMode;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.face_retouching_natural, color: Colors.white, size: 24),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Viewport con Cuadrícula 3x3
            Expanded(
              child: ClipRRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview de Cámara
                    Center(
                      child: Transform.scale(
                        scale: 1 / (_controller!.value.aspectRatio * deviceRatio),
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    
                    // Cuadrícula 3x3 (Grid lines)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        return Stack(
                          children: [
                            // Vertical lines
                            Positioned(
                              left: width / 3,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 0.8, color: Colors.white.withOpacity(0.35)),
                            ),
                            Positioned(
                              left: (width / 3) * 2,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 0.8, color: Colors.white.withOpacity(0.35)),
                            ),
                            // Horizontal lines
                            Positioned(
                              left: 0,
                              right: 0,
                              top: height / 3,
                              child: Container(height: 0.8, color: Colors.white.withOpacity(0.35)),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: (height / 3) * 2,
                              child: Container(height: 0.8, color: Colors.white.withOpacity(0.35)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Bar / Controles
            Container(
              color: Colors.black,
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de Modos (Vídeo, AI CAM, etc.)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cameraModes.length,
                      itemBuilder: (context, index) {
                        final mode = _cameraModes[index];
                        final isSelected = mode == _selectedMode;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMode = mode;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              mode,
                              style: TextStyle(
                                color: isSelected ? Colors.amber : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Fila de Disparo y Galería
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón de Galería / Última Foto (Izquierda)
                        GestureDetector(
                          onTap: _openGallery,
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 2),
                              color: Colors.white10,
                              image: _lastImagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(_lastImagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=120'),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                        
                        // Botón de Disparo (Centro)
                        GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2.5),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                        // Botón de Voltear Cámara (Derecha)
                        GestureDetector(
                          onTap: _toggleCamera,
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white10,
                            ),
                            child: const Icon(
                              Icons.cached,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
