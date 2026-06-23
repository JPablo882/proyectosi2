import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ChangeDetectorRef } from '@angular/core';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-proyectos',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './proyectos.html',
  styleUrl: './proyectos.scss'
})
export class ProyectosComponent implements OnInit, OnDestroy {

  proyectos: any[] = [];
  terminoBusqueda: string = '';
  private pollingInterval: any;
  empleados: any[] = [];
  listaIngenieros: any[] = [];
  listaResidentes: any[] = [];
  listaMaestros: any[] = [];
  listaAlbaniles: any[] = [];
  listaAyudantes: any[] = [];

  // Active / filtered lists for the modal exclusions
  listaIngenierosActivos: any[] = [];
  listaResidentesActivos: any[] = [];
  listaMaestrosActivos: any[] = [];
  listaAlbanilesActivos: any[] = [];
  listaAyudantesActivos: any[] = [];

  mostrarModalAsignacion: boolean = false;
  proyectoSeleccionado: any = null;
  idIngenieroSel: any = null;
  idResidenteSel: any = null;
  idMaestroSel: any = null;
  idAlbanilesSel: number[] = [];
  idAyudantesSel: number[] = [];

  proyecto = {

    id_usuarios: 1,
    nombre: '',
    ubicacion: '',
    fecha_inicio: '',
    fecha_fin: '',
    estado: ''

  };

  constructor(
  private api: ApiService,
  private cd: ChangeDetectorRef
){}

  ngOnInit(): void {

    this.cargarProyectos();
    this.cargarEmpleados();

    // Optimización: Auto-refrescar la lista cada 3 segundos en segundo plano
    this.pollingInterval = setInterval(() => {
      this.cargarProyectosSilencioso();
    }, 3000);

  }

  ngOnDestroy(): void {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }

  cargarProyectos(){

    this.api.obtenerProyectosConEstadoFinanciero()
    .subscribe({

      next: (resp:any) => {

  console.log(resp);

  this.proyectos = resp;

  this.cd.detectChanges();

},

      error: (err) => {

        console.log(err);

      }

    });

  }

  // Versión sin console.log para no llenar la consola durante el auto-refresh
  cargarProyectosSilencioso(){
    this.api.obtenerProyectosConEstadoFinanciero()
    .subscribe({
      next: (resp:any) => {
        // Solo actualizamos si hay cambios reales para no interrumpir la interfaz
        if (JSON.stringify(this.proyectos) !== JSON.stringify(resp)) {
          this.proyectos = resp;
          this.cd.detectChanges();
        }
      },
      error: (err) => {
        // Ignorar errores silenciosos de red
      }
    });
  }

  get proyectosFiltrados() {
    if (!this.terminoBusqueda) {
      return this.proyectos;
    }
    const termino = this.terminoBusqueda.toLowerCase();
    return this.proyectos.filter(p => {
      const id = p.id_proyecto?.toString() || '';
      const nombre = (p.nombre || '').toLowerCase();
      const cliente = (p.cliente || '').toLowerCase();
      const inicio = (p.fecha_inicio || '').toLowerCase();
      const estadoPago = (p.estado_pago || '').toLowerCase();
      const estadoProy = (p.estado_proyecto || '').toLowerCase();

      return id.includes(termino) ||
             nombre.includes(termino) ||
             cliente.includes(termino) ||
             inicio.includes(termino) ||
             estadoPago.includes(termino) ||
             estadoProy.includes(termino);
    });
  }

  actualizarEstadoProyecto(idProyecto: number, event: any){
    const nuevoEstado = event.target.value;
    this.api.actualizarProyecto(idProyecto, { estado: nuevoEstado })
    .subscribe({
      next: () => {
        alert('Estado del proyecto actualizado correctamente.');
        this.cargarProyectos();
      },
      error: (err) => {
        console.error(err);
        alert('Error al actualizar el estado del proyecto.');
        this.cargarProyectos();
      }
    });
  }

  registrarProyecto(){

    this.api.crearProyecto(this.proyecto)
    .subscribe({

      next: () => {

        alert('Proyecto registrado');

        this.proyecto = {

          id_usuarios: 1,
          nombre: '',
          ubicacion: '',
          fecha_inicio: '',
          fecha_fin: '',
          estado: ''

        };

        this.cargarProyectos();

      },

      error: (err) => {

        console.log(err);

        alert('Error al registrar');

      }

    });

  }

  eliminarProyecto(id: number){

    const confirmar = confirm(
      '¿Deseas eliminar este proyecto?'
    );

    if(!confirmar) return;

    this.api.eliminarProyecto(id)
    .subscribe({

      next: () => {

        alert('Proyecto eliminado');

        this.cargarProyectos();

      },

      error: (err) => {

        console.log(err);

      }

    });

  }

  cargarEmpleados() {
    this.api.obtenerEmpleados()
    .subscribe({
      next: (resp: any) => {
        this.empleados = resp.empleados || resp || [];
        
        this.listaIngenieros = this.empleados.filter(e => {
          const cargo = (e.cargo || '').toLowerCase();
          return cargo.includes('ing') || cargo.includes('arq');
        });
        
        this.listaResidentes = this.empleados.filter(e => {
          const cargo = (e.cargo || '').toLowerCase();
          return cargo.includes('residente');
        });
        
        this.listaMaestros = this.empleados.filter(e => {
          const cargo = (e.cargo || '').toLowerCase();
          return cargo.includes('maestro');
        });

        this.listaAlbaniles = this.empleados.filter(e => {
          const cargo = (e.cargo || '').toLowerCase();
          return cargo.includes('albañil') || cargo.includes('albanil');
        });

        this.listaAyudantes = this.empleados.filter(e => {
          const cargo = (e.cargo || '').toLowerCase();
          return cargo.includes('ayudante');
        });

        this.cd.detectChanges();
      },
      error: (err) => {
        console.error('Error al cargar empleados:', err);
      }
    });
  }

  abrirModalAsignar(proyecto: any) {
    this.proyectoSeleccionado = proyecto;
    
    // 1. Encontrar IDs de empleados ocupados en otros proyectos activos
    const occupiedIds = new Set<number>();
    for (const p of this.proyectos) {
      if (p.id_proyecto === proyecto.id_proyecto) {
        continue; // Omitir el proyecto actual que estamos editando
      }
      
      // Proyectos activos (que no están finalizados)
      if (p.estado_proyecto !== 'Finalizado') {
        if (p.id_ingeniero) occupiedIds.add(Number(p.id_ingeniero));
        if (p.id_residente) occupiedIds.add(Number(p.id_residente));
        if (p.id_maestro) occupiedIds.add(Number(p.id_maestro));
        
        if (p.id_albaniles && Array.isArray(p.id_albaniles)) {
          p.id_albaniles.forEach((id: any) => occupiedIds.add(Number(id)));
        }
        if (p.id_ayudantes && Array.isArray(p.id_ayudantes)) {
          p.id_ayudantes.forEach((id: any) => occupiedIds.add(Number(id)));
        }
      }
    }

    // 2. Filtrar las listas para el modal:
    // Mostrar empleados libres + los que ya pertenecen al proyecto actual
    this.listaIngenierosActivos = this.listaIngenieros.filter(e => 
      !occupiedIds.has(e.id_empleados) || e.id_empleados === proyecto.id_ingeniero
    );
    this.listaResidentesActivos = this.listaResidentes.filter(e => 
      !occupiedIds.has(e.id_empleados) || e.id_empleados === proyecto.id_residente
    );
    this.listaMaestrosActivos = this.listaMaestros.filter(e => 
      !occupiedIds.has(e.id_empleados) || e.id_empleados === proyecto.id_maestro
    );
    this.listaAlbanilesActivos = this.listaAlbaniles.filter(e => 
      !occupiedIds.has(e.id_empleados) || (proyecto.id_albaniles || []).includes(e.id_empleados)
    );
    this.listaAyudantesActivos = this.listaAyudantes.filter(e => 
      !occupiedIds.has(e.id_empleados) || (proyecto.id_ayudantes || []).includes(e.id_empleados)
    );

    // 3. Inicializar variables de selección del modal
    this.idIngenieroSel = proyecto.id_ingeniero || null;
    this.idResidenteSel = proyecto.id_residente || null;
    this.idMaestroSel = proyecto.id_maestro || null;
    this.idAlbanilesSel = proyecto.id_albaniles ? [...proyecto.id_albaniles] : [];
    this.idAyudantesSel = proyecto.id_ayudantes ? [...proyecto.id_ayudantes] : [];
    
    this.mostrarModalAsignacion = true;
    this.cd.detectChanges();
  }

  isAlbanilSeleccionado(id: number): boolean {
    return this.idAlbanilesSel.includes(id);
  }

  toggleAlbanil(id: number) {
    if (this.isAlbanilSeleccionado(id)) {
      this.idAlbanilesSel = this.idAlbanilesSel.filter(x => x !== id);
    } else {
      this.idAlbanilesSel.push(id);
    }
  }

  isAyudanteSeleccionado(id: number): boolean {
    return this.idAyudantesSel.includes(id);
  }

  toggleAyudante(id: number) {
    if (this.isAyudanteSeleccionado(id)) {
      this.idAyudantesSel = this.idAyudantesSel.filter(x => x !== id);
    } else {
      this.idAyudantesSel.push(id);
    }
  }

  cerrarModalAsignacion() {
    this.mostrarModalAsignacion = false;
    this.proyectoSeleccionado = null;
    this.idIngenieroSel = null;
    this.idResidenteSel = null;
    this.idMaestroSel = null;
    this.idAlbanilesSel = [];
    this.idAyudantesSel = [];
    this.cd.detectChanges();
  }

  guardarAsignacion() {
    if (!this.idIngenieroSel || this.idIngenieroSel === 'null') {
      alert('Debe asignar un Ingeniero o Arquitecto obligatoriamente.');
      return;
    }
    if (!this.idResidenteSel || this.idResidenteSel === 'null') {
      alert('Debe asignar un Residente de Obras obligatoriamente.');
      return;
    }
    if (!this.idMaestroSel || this.idMaestroSel === 'null') {
      alert('Debe asignar un Maestro de Obra obligatoriamente.');
      return;
    }

    const payload = {
      id_ingeniero: this.idIngenieroSel === 'null' ? null : Number(this.idIngenieroSel),
      id_residente: this.idResidenteSel === 'null' ? null : Number(this.idResidenteSel),
      id_maestro: this.idMaestroSel === 'null' ? null : Number(this.idMaestroSel),
      id_albaniles: this.idAlbanilesSel,
      id_ayudantes: this.idAyudantesSel
    };

    this.api.actualizarProyecto(this.proyectoSeleccionado.id_proyecto, payload)
    .subscribe({
      next: () => {
        alert('Personal asignado correctamente al proyecto.');
        this.cerrarModalAsignacion();
        this.cargarProyectos();
      },
      error: (err) => {
        console.error('Error al asignar personal:', err);
        alert('Error al guardar la asignación.');
      }
    });
  }
}