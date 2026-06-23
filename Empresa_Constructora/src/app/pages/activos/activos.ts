import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';

@Component({
  selector: 'app-activos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './activos.html',
  styleUrl: './activos.scss'
})
export class ActivosComponent implements OnInit {
  activeTab: string = 'inventario';
  
  activos: any[] = [];
  proyectos: any[] = [];
  mantenimientos: any[] = [];
  historial: any[] = [];
  
  // Filtros
  filtroTexto: string = '';
  filtroEstado: string = '';

  // Formulario nuevo activo
  nuevoActivo = {
    nombre: '',
    tipo_activo: 'Maquinaria Pesada',
    codigo_activo: '',
    fechacompra: '',
    valor_compra: 0,
    vida_util: 5,
    valor_residual: 0,
    estado: 'Disponible'
  };

  // Formulario nuevo mantenimiento
  nuevoMantenimiento = {
    id_activo: '',
    fecha: '',
    tipo: 'Preventivo',
    descripcion: '',
    costo: 0,
    estado: 'Programado'
  };

  // Drag & Drop state
  draggedAsset: any = null;

  // Mapa
  mapUrl: SafeResourceUrl | null = null;
  activoSeleccionadoMapa: any = null;

  // Calendario
  diasCalendario: any[] = [];
  mesActual: Date = new Date();
  mesNombre: string = '';

  // Historial del activo seleccionado
  activoSeleccionadoHistorial: any = null;
  historialFiltrado: any[] = [];

  // Modales
  isModalActivoOpen = false;
  isModalMantenimientoOpen = false;

  constructor(
    private apiService: ApiService,
    private sanitizer: DomSanitizer
  ) {}

  ngOnInit() {
    this.cargarDatos();
    this.inicializarCalendario();
  }

  cargarDatos() {
    this.apiService.obtenerActivos().subscribe({
      next: (res) => {
        this.activos = res || [];
        if (this.activos.length > 0) {
          if (!this.activoSeleccionadoHistorial) {
            this.seleccionarActivoHistorial(this.activos[0]);
          }
          if (!this.activoSeleccionadoMapa) {
            this.seleccionarActivoMapa(this.activos[0]);
          }
        }
        this.llenarEventosCalendario();
      },
      error: (err) => console.error('Error al cargar activos:', err)
    });

    this.apiService.obtenerProyectos().subscribe({
      next: (res) => {
        this.proyectos = res || [];
      },
      error: (err) => console.error('Error al cargar proyectos:', err)
    });

    this.apiService.obtenerMantenimientos().subscribe({
      next: (res) => {
        this.mantenimientos = res || [];
        this.llenarEventosCalendario();
      },
      error: (err) => console.error('Error al cargar mantenimientos:', err)
    });

    this.apiService.obtenerHistorialActivos().subscribe({
      next: (res) => {
        this.historial = res || [];
        if (this.activoSeleccionadoHistorial) {
          this.filtrarHistorialActivo(this.activoSeleccionadoHistorial.id_activo);
        }
      },
      error: (err) => console.error('Error al cargar historial:', err)
    });
  }

  // --- FILTRADO DE INVENTARIO ---
  get activosFiltrados() {
    return this.activos.filter(a => {
      const matchTexto = a.nombre.toLowerCase().includes(this.filtroTexto.toLowerCase()) || 
                         a.codigo_activo.toLowerCase().includes(this.filtroTexto.toLowerCase()) ||
                         a.tipo_activo.toLowerCase().includes(this.filtroTexto.toLowerCase());
      
      const matchEstado = this.filtroEstado ? a.estado === this.filtroEstado : true;
      return matchTexto && matchEstado;
    });
  }

  obtenerNombreProyecto(idProyecto: any): string {
    if (!idProyecto) return 'Sin asignar';
    const p = this.proyectos.find(proj => proj.id_proyecto == idProyecto);
    return p ? p.nombre : `Proyecto #${idProyecto}`;
  }

  // --- GESTIÓN DE NUEVOS ACTIVOS ---
  crearActivo() {
    if (!this.nuevoActivo.nombre || !this.nuevoActivo.codigo_activo) {
      alert('Por favor ingresa el nombre y código del activo.');
      return;
    }

    this.apiService.crearActivo(this.nuevoActivo).subscribe({
      next: (activoCreado) => {
        // Log histórico
        const log = {
          id_activo: activoCreado.id_activo,
          fecha: new Date().toISOString().split('T')[0],
          accion: 'Adquisición',
          detalles: `Adquirido por valor de ${this.nuevoActivo.valor_compra} Bs. Vida útil de ${this.nuevoActivo.vida_util} años.`
        };

        this.apiService.crearHistorialActivo(log).subscribe(() => {
          this.cargarDatos();
          this.isModalActivoOpen = false;
          // Reset formulario
          this.nuevoActivo = {
            nombre: '',
            tipo_activo: 'Maquinaria Pesada',
            codigo_activo: '',
            fechacompra: new Date().toISOString().split('T')[0],
            valor_compra: 0,
            vida_util: 5,
            valor_residual: 0,
            estado: 'Disponible'
          };
        });
      },
      error: (err) => alert('Error al crear el activo: ' + err.error?.detail || err.message)
    });
  }

  eliminarActivo(id: any) {
    if (confirm('¿Está seguro de eliminar este activo fijo?')) {
      this.apiService.eliminarActivo(id).subscribe({
        next: () => {
          this.cargarDatos();
        },
        error: (err) => alert('Error al eliminar: ' + err.error?.detail || err.message)
      });
    }
  }

  // --- DRAG AND DROP (CU26) ---
  onDragStart(event: DragEvent, asset: any) {
    this.draggedAsset = asset;
    if (event.dataTransfer) {
      event.dataTransfer.setData('text/plain', asset.id_activo.toString());
      event.dataTransfer.effectAllowed = 'move';
    }
  }

  onDragOver(event: DragEvent) {
    event.preventDefault();
  }

  onDrop(event: DragEvent, project: any) {
    event.preventDefault();
    if (!this.draggedAsset) return;

    if (this.draggedAsset.estado === 'Mantenimiento') {
      alert('No se puede asignar un activo que está en mantenimiento.');
      return;
    }

    const activoEdit = {
      ...this.draggedAsset,
      id_proyecto: project.id_proyecto,
      estado: 'Asignado'
    };

    this.apiService.actualizarActivo(this.draggedAsset.id_activo, activoEdit).subscribe({
      next: () => {
        // Registrar en historial
        const log = {
          id_activo: this.draggedAsset.id_activo,
          fecha: new Date().toISOString().split('T')[0],
          accion: 'Asignación',
          detalles: `Asignado al proyecto: ${project.nombre}.`
        };

        this.apiService.crearHistorialActivo(log).subscribe(() => {
          this.cargarDatos();
          this.draggedAsset = null;
        });
      },
      error: (err) => alert('Error al asignar activo: ' + err.message)
    });
  }

  liberarActivo(asset: any) {
    const activoEdit = {
      ...asset,
      id_proyecto: null,
      estado: 'Disponible'
    };

    this.apiService.actualizarActivo(asset.id_activo, activoEdit).subscribe({
      next: () => {
        const log = {
          id_activo: asset.id_activo,
          fecha: new Date().toISOString().split('T')[0],
          accion: 'Devolución',
          detalles: 'Devuelto de obra a almacén central.'
        };

        this.apiService.crearHistorialActivo(log).subscribe(() => {
          this.cargarDatos();
        });
      },
      error: (err) => alert('Error al liberar: ' + err.message)
    });
  }

  // --- MAPA INTERACTIVO (CU27) ---
  seleccionarActivoMapa(asset: any) {
    this.activoSeleccionadoMapa = asset;
    this.actualizarMapa();
  }

  actualizarMapa() {
    if (!this.activoSeleccionadoMapa) {
      this.mapUrl = null;
      return;
    }

    let lat = -17.7818; // Santa Cruz Centro
    let lon = -63.1804;

    if (this.activoSeleccionadoMapa.id_proyecto) {
      // Simular coordenadas por ID de proyecto
      const id = Number(this.activoSeleccionadoMapa.id_proyecto);
      const coords = [
        { lat: -17.736012, lon: -63.116847 }, // Pinares/pollerita
        { lat: -17.756123, lon: -63.136234 },
        { lat: -17.771234, lon: -63.156345 },
        { lat: -17.791567, lon: -63.196456 }
      ];
      const match = coords[id % coords.length];
      lat = match.lat;
      lon = match.lon;
    } else {
      // Almacén central (Disponible)
      lat = -17.7818;
      lon = -63.1804;
    }

    const url = `https://maps.google.com/maps?q=${lat},${lon}&z=16&output=embed`;
    this.mapUrl = this.sanitizer.bypassSecurityTrustResourceUrl(url);
  }

  // --- CALENDARIO DE MANTENIMIENTO (CU28) ---
  inicializarCalendario() {
    const nombresMeses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    this.mesNombre = `${nombresMeses[this.mesActual.getMonth()]} ${this.mesActual.getFullYear()}`;

    const anio = this.mesActual.getFullYear();
    const mes = this.mesActual.getMonth();

    const primerDiaSemana = new Date(anio, mes, 1).getDay(); // Domingo = 0
    const totalDias = new Date(anio, mes + 1, 0).getDate();

    const dias = [];

    // Celdas vacías del mes anterior
    for (let i = 0; i < primerDiaSemana; i++) {
      dias.push({ dia: '', fechaStr: '', eventos: [] });
    }

    // Celdas del mes actual
    for (let d = 1; d <= totalDias; d++) {
      const fechaStr = `${anio}-${(mes + 1).toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
      dias.push({
        dia: d,
        fechaStr: fechaStr,
        eventos: []
      });
    }

    this.diasCalendario = dias;
    this.llenarEventosCalendario();
  }

  llenarEventosCalendario() {
    if (this.diasCalendario.length === 0 || this.mantenimientos.length === 0) return;

    this.diasCalendario.forEach(celda => {
      if (!celda.fechaStr) return;
      celda.eventos = this.mantenimientos.filter(m => {
        const mFechaStr = m.fecha ? m.fecha.toString().split('T')[0] : '';
        return mFechaStr === celda.fechaStr;
      }).map(m => {
        const activo = this.activos.find(a => a.id_activo === m.id_activo);
        return {
          ...m,
          nombreActivo: activo ? activo.nombre : `Activo #${m.id_activo}`
        };
      });
    });
  }

  mesAnterior() {
    this.mesActual.setMonth(this.mesActual.getMonth() - 1);
    this.mesActual = new Date(this.mesActual);
    this.inicializarCalendario();
  }

  mesSiguiente() {
    this.mesActual.setMonth(this.mesActual.getMonth() + 1);
    this.mesActual = new Date(this.mesActual);
    this.inicializarCalendario();
  }

  abrirProgramarMantenimiento(fechaStr: string) {
    this.nuevoMantenimiento.fecha = fechaStr;
    this.isModalMantenimientoOpen = true;
  }

  programarMantenimiento() {
    if (!this.nuevoMantenimiento.id_activo || !this.nuevoMantenimiento.fecha) {
      alert('Por favor selecciona el activo y la fecha de mantenimiento.');
      return;
    }

    this.apiService.crearMantenimiento(this.nuevoMantenimiento).subscribe({
      next: () => {
        // Cambiar estado del activo
        const activo = this.activos.find(a => a.id_activo == this.nuevoMantenimiento.id_activo);
        if (activo) {
          const activoEdit = {
            ...activo,
            estado: 'Mantenimiento'
          };
          this.apiService.actualizarActivo(activo.id_activo, activoEdit).subscribe(() => {
            // Historial
            const log = {
              id_activo: activo.id_activo,
              fecha: this.nuevoMantenimiento.fecha,
              accion: 'Mantenimiento',
              detalles: `Programado mantenimiento ${this.nuevoMantenimiento.tipo}: ${this.nuevoMantenimiento.descripcion}. Costo estimado: ${this.nuevoMantenimiento.costo} Bs.`
            };
            this.apiService.crearHistorialActivo(log).subscribe(() => {
              this.cargarDatos();
              this.isModalMantenimientoOpen = false;
              // Reset
              this.nuevoMantenimiento = {
                id_activo: '',
                fecha: '',
                tipo: 'Preventivo',
                descripcion: '',
                costo: 0,
                estado: 'Programado'
              };
            });
          });
        }
      },
      error: (err) => alert('Error al programar mantenimiento: ' + err.message)
    });
  }

  // --- HISTORIAL DEL ACTIVO (CU29) ---
  seleccionarActivoHistorial(asset: any) {
    this.activoSeleccionadoHistorial = asset;
    this.filtrarHistorialActivo(asset.id_activo);
  }

  filtrarHistorialActivo(idActivo: any) {
    this.historialFiltrado = this.historial
      .filter(h => h.id_activo == idActivo)
      .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime());
  }
}
