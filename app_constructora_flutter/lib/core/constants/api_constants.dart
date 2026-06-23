class ApiConstants {
  // URL apuntando a la IP pública de AWS (Nube)
  //static const String baseUrl = 'http://18.221.96.239:8000';

  // URL apuntando a la IP local de tu computadora en la red Wi-Fi (para celular físico de prueba local)
  static const String baseUrl = 'http://127.0.0.1:8000';

  // URL local para el emulador de Android (10.0.2.2 apunta al localhost de la máquina host)
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // Endpoints del backend
  static const String login = '/login/usuario';
  static const String register = '/login/registro';
  static const String loginGlobal = '/login/login-global';
  static const String registerGlobal = '/login/registro-global';
  static const String seleccionarEmpresa = '/login/seleccionar-empresa';
  static const String cambiarContrasena = '/login/cambiar-contrasena';
  static const String logout = '/login/cerrar-sesion';
  static const String profile = '/usuarios';
  static const String projects = '/proyectos';
  static const String cotizarAudio = '/ia/cotizar-audio';
  static const String cotizaciones = '/cotizaciones';
  static const String misCotizaciones = '/cotizaciones/mis-cotizaciones';
}
