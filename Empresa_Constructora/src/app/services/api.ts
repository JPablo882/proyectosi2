import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, timeout } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ApiService {

  private baseUrl = 'http://127.0.0.1:8000';

  constructor(private http: HttpClient) {}

  private getHeaders() {
    let empresaId = '1';
    let usuarioId = '1';

    const empresaDataStr = localStorage.getItem('empresa');
    if (empresaDataStr) {
      try {
        const empresaData = JSON.parse(empresaDataStr);
        if (empresaData.id_empresa) {
          empresaId = empresaData.id_empresa.toString();
        }
        if (empresaData.id_usuario_admin) {
          usuarioId = empresaData.id_usuario_admin.toString();
        }
      } catch (e) {
        console.error('Error parsing empresa data in ApiService:', e);
      }
    }

    const usuarioDataStr = localStorage.getItem('usuario');
    if (usuarioDataStr) {
      try {
        const usuarioData = JSON.parse(usuarioDataStr);
        if (usuarioData.id_empresa) {
          empresaId = usuarioData.id_empresa.toString();
        }
        if (usuarioData.id_usuario) {
          usuarioId = usuarioData.id_usuario.toString();
        }
      } catch (e) {
        console.error('Error parsing usuario data in ApiService:', e);
      }
    }

    return {
      'X-Empresa-Id': empresaId,
      'X-Usuario-Id': usuarioId
    };
  }

  registrarEmpresa(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/empresas-saas/registrar`,
      data
    );
  }

  actualizarLogoEmpresa(idEmpresa: number, logoBase64: string): Observable<any> {
    return this.http.put(
      `${this.baseUrl}/empresas-saas/${idEmpresa}/logo`,
      { logo: logoBase64 }
    );
  }

  loginEmpresa(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/login/empresa`,
      data
    );
  }

  loginUsuario(data: any, empresaId: string): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/login/usuario`,
      data,
      {
        headers: {
          'X-Empresa-Id': empresaId
        }
      }
    );
  }

  solicitarRecuperacion(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/auth/empresa/solicitar-recuperacion`,
      data
    );
  }

  verificarToken(token: string): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/auth/empresa/verificar-token?token=${token}`
    );
  }

  restablecerContrasena(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/auth/empresa/restablecer-contrasena`,
      data
    );
  }

  crearCliente(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/clientes`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerClientes(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/clientes`,
      { headers: this.getHeaders() }
    );
  }

  eliminarCliente(id: any): Observable<any> {
    return this.http.delete(
      `${this.baseUrl}/clientes/${id}`,
      { headers: this.getHeaders() }
    );
  }

  crearProyecto(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/proyectos`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerProyectos(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/proyectos`,
      { headers: this.getHeaders() }
    );
  }

  eliminarProyecto(id: any): Observable<any> {
    return this.http.delete(
      `${this.baseUrl}/proyectos/${id}`,
      { headers: this.getHeaders() }
    );
  }

  obtenerProyectosConEstadoFinanciero(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/casos-uso/hu33/proyectos/estado-financiero`,
      { headers: this.getHeaders() }
    );
  }

  actualizarProyecto(id: any, data: any): Observable<any> {
    return this.http.put(
      `${this.baseUrl}/proyectos/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  preguntarIA(pregunta: string, historial: any[] = []): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/ia/preguntar-contexto`,
      { pregunta: pregunta, historial: historial },
      { headers: this.getHeaders() }
    ).pipe(
      timeout(60000)
    );
  }

  crearEmpleado(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/empleados`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerEmpleados(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/empleados`,
      { headers: this.getHeaders() }
    );
  }

  eliminarEmpleado(id: number): Observable<any> {
    return this.http.delete(
      `${this.baseUrl}/empleados/${id}`,
      { headers: this.getHeaders() }
    );
  }

  actualizarEmpleado(id: number, data: any): Observable<any> {
    return this.http.put(
      `${this.baseUrl}/empleados/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  crearProveedor(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/proveedores`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerProveedores(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/proveedores`,
      { headers: this.getHeaders() }
    );
  }

  crearCompra(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/compras`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerCompras(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/compras`,
      { headers: this.getHeaders() }
    );
  }

  crearDetalleCompra(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/detalle-compras`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerDetallesCompra(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/detalle-compras`,
      { headers: this.getHeaders() }
    );
  }

  obtenerMateriales(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/materiales`,
      { headers: this.getHeaders() }
    );
  }

  crearMaterial(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/materiales`,
      data,
      { headers: this.getHeaders() }
    );
  }

  ocuparMaterial(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/materiales/ocupar`,
      data,
      { headers: this.getHeaders() }
    );
  }

  calcularPresupuesto(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/presupuesto-calculos/calcular-simple`,
      data,
      { headers: this.getHeaders() }
    );
  }

  preguntarAudio(data: FormData): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/ia/preguntar-audio-contexto`,
      data,
      { headers: this.getHeaders() }
    ).pipe(
      timeout(90000)
    );
  }

  crearAvance(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/avances`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerAvances(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/avances`,
      { headers: this.getHeaders() }
    );
  }

  obtenerAvancesProyecto(id: number): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/avances/proyecto/${id}`,
      { headers: this.getHeaders() }
    );
  }

  obtenerDocumentos(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/documentos`,
      { headers: this.getHeaders() }
    );
  }

  crearDocumento(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/documentos`,
      data,
      { headers: this.getHeaders() }
    );
  }

  eliminarDocumento(id: number): Observable<any> {
    return this.http.delete(
      `${this.baseUrl}/documentos/${id}`,
      { headers: this.getHeaders() }
    );
  }

  subirDocumento(data: FormData): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/documentos/subir`,
      data,
      { headers: this.getHeaders() }
    );
  }

  obtenerMovimientosFinancieros(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/movimientos-financieros`,
      { headers: this.getHeaders() }
    );
  }

  obtenerVentas(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/ventas`,
      { headers: this.getHeaders() }
    );
  }

  obtenerDetalleProyectoCliente(idProyecto: number): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/casos-uso/hu33/cliente/proyectos/${idProyecto}`,
      { headers: this.getHeaders() }
    );
  }

  // ===== ACTIVOS FIJOS =====
  obtenerActivos(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/activos-fijos`,
      { headers: this.getHeaders() }
    );
  }

  crearActivo(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/activos-fijos`,
      data,
      { headers: this.getHeaders() }
    );
  }

  actualizarActivo(id: any, data: any): Observable<any> {
    return this.http.put(
      `${this.baseUrl}/activos-fijos/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  eliminarActivo(id: any): Observable<any> {
    return this.http.delete(
      `${this.baseUrl}/activos-fijos/${id}`,
      { headers: this.getHeaders() }
    );
  }

  // ===== MANTENIMIENTO ACTIVOS =====
  obtenerMantenimientos(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/mantenimiento-activos`,
      { headers: this.getHeaders() }
    );
  }

  crearMantenimiento(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/mantenimiento-activos`,
      data,
      { headers: this.getHeaders() }
    );
  }

  // ===== HISTORIAL DE ACTIVOS =====
  obtenerHistorialActivos(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/activo-historicos`,
      { headers: this.getHeaders() }
    );
  }

  crearHistorialActivo(data: any): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/activo-historicos`,
      data,
      { headers: this.getHeaders() }
    );
  }

  // ===== APROBACION DE COMPRAS =====
  aprobarCompra(id: number): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/compras/${id}/aprobar`,
      {},
      { headers: this.getHeaders() }
    );
  }

  rechazarCompra(id: number): Observable<any> {
    return this.http.post(
      `${this.baseUrl}/compras/${id}/rechazar`,
      {},
      { headers: this.getHeaders() }
    );
  }

  obtenerEstadoResultados(): Observable<any> {
    return this.http.get(
      `${this.baseUrl}/reportes/estado-resultados`,
      { headers: this.getHeaders() }
    );
  }
}