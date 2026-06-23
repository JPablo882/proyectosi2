import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ChangeDetectorRef } from '@angular/core';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-rrhh',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './rrhh.html',
  styleUrl: './rrhh.scss'
})
export class RrhhComponent implements OnInit {

  // Control de pestañas
  activeTab: 'personal' | 'organigrama' = 'personal';

  empleado = {
    nombre: '',
    cargo: '',
    salario: '',
    telefono: ''
  };

  terminoBusqueda: string = '';
  empleados: any[] = [];
  proyectos: any[] = [];
  selectedProyectoId: number | null = null;
  selectedEmpleadoForKpi: any = null;

  isEditModalOpen = false;
  editEmpleadoData = {
    id_empleados: 0,
    nombre: '',
    cargo: '',
    salario: 0,
    telefono: ''
  };

  constructor(
    private api: ApiService,
    private cd: ChangeDetectorRef
  ){}

  ngOnInit(): void {
    this.cargarEmpleados();
    this.cargarProyectos();
  }

  seleccionarCargo(cargo: string) {
    this.empleado.cargo = cargo;
    this.cd.detectChanges();
  }

  cargarEmpleados(){
    this.api.obtenerEmpleados().subscribe({
      next: (resp: any) => {
        this.empleados = resp.empleados || resp;
        // Seleccionar por defecto el primer empleado si no hay seleccionado
        if (this.empleados.length > 0 && !this.selectedEmpleadoForKpi) {
          this.selectedEmpleadoForKpi = this.empleados[0];
        }
        this.cd.detectChanges();
      },
      error: (err) => {
        console.error('Error al cargar empleados:', err);
      }
    });
  }

  get empleadosFiltrados() {
    if (!this.terminoBusqueda) {
      return this.empleados;
    }
    const termino = this.terminoBusqueda.toLowerCase();
    return this.empleados.filter(e => {
      const id = e.id_empleados?.toString() || '';
      const nombre = (e.nombre || '').toLowerCase();
      const cargo = (e.cargo || '').toLowerCase();

      return id.includes(termino) ||
             nombre.includes(termino) ||
             cargo.includes(termino);
    });
  }

  cargarProyectos() {
    this.api.obtenerProyectos().subscribe({
      next: (resp: any) => {
        this.proyectos = resp || [];
        if (this.proyectos.length > 0 && !this.selectedProyectoId) {
          this.selectedProyectoId = this.proyectos[0].id_proyecto;
        }
        this.cd.detectChanges();
      },
      error: (err) => {
        console.error('Error al cargar proyectos:', err);
      }
    });
  }

  registrarEmpleado(){
    this.api.crearEmpleado(this.empleado).subscribe({
      next: () => {
        alert('Empleado registrado exitosamente');
        this.empleado = {
          nombre: '',
          cargo: '',
          salario: '',
          telefono: ''
        };
        this.cargarEmpleados();
      },
      error: (err) => {
        console.error(err);
        alert('Error al registrar empleado');
      }
    });
  }

  eliminarEmpleado(id: number){
    if(!confirm('¿Está seguro de eliminar este empleado?')) return;
    this.api.eliminarEmpleado(id).subscribe({
      next: () => {
        alert('Empleado eliminado exitosamente');
        this.cargarEmpleados();
      },
      error: (err) => {
        console.error(err);
        alert('Error al eliminar empleado');
      }
    });
  }

  editarEmpleado(emp: any){
    this.editEmpleadoData = {
      id_empleados: emp.id_empleados,
      nombre: emp.nombre,
      cargo: emp.cargo,
      salario: emp.salario,
      telefono: emp.telefono
    };
    this.isEditModalOpen = true;
  }

  guardarEdicion(){
    if (!this.editEmpleadoData.nombre || !this.editEmpleadoData.telefono) {
      alert('Por favor complete el nombre y teléfono');
      return;
    }
    this.api.actualizarEmpleado(this.editEmpleadoData.id_empleados, this.editEmpleadoData).subscribe({
      next: () => {
        alert('Empleado actualizado correctamente');
        this.isEditModalOpen = false;
        this.cargarEmpleados();
      },
      error: (err) => {
        console.error(err);
        alert('Error al actualizar empleado');
      }
    });
  }

  cerrarModal(){
    this.isEditModalOpen = false;
  }

  // --- LÓGICA DE ORGANIGRAMA Y KPIs ---

  obtenerProyectoSeleccionado() {
    return this.proyectos.find(p => p.id_proyecto == this.selectedProyectoId);
  }

  obtenerEmpleadoPorId(id: any): any {
    if (!id) return null;
    return this.empleados.find(e => e.id_empleados == id);
  }

  obtenerEmpleadosPorIds(ids: any): any[] {
    if (!ids || !Array.isArray(ids)) return [];
    return this.empleados.filter(e => ids.includes(e.id_empleados));
  }

  obtenerEmpleadosDisponibles(): any[] {
    const asignadosIds = new Set<number>();
    for (const p of this.proyectos) {
      if (p.id_ingeniero) asignadosIds.add(Number(p.id_ingeniero));
      if (p.id_residente) asignadosIds.add(Number(p.id_residente));
      if (p.id_maestro) asignadosIds.add(Number(p.id_maestro));
      if (p.id_albaniles && Array.isArray(p.id_albaniles)) {
        p.id_albaniles.forEach((id: any) => asignadosIds.add(Number(id)));
      }
      if (p.id_ayudantes && Array.isArray(p.id_ayudantes)) {
        p.id_ayudantes.forEach((id: any) => asignadosIds.add(Number(id)));
      }
    }
    return this.empleados.filter(e => !asignadosIds.has(Number(e.id_empleados)));
  }

  seleccionarProyecto(id: any) {
    this.selectedProyectoId = Number(id);
    // Seleccionar por defecto el ingeniero o primer miembro del proyecto seleccionado para mostrar sus KPIs
    const p = this.obtenerProyectoSeleccionado();
    if (p) {
      if (p.id_ingeniero) {
        this.selectedEmpleadoForKpi = this.obtenerEmpleadoPorId(p.id_ingeniero);
      } else if (p.id_residente) {
        this.selectedEmpleadoForKpi = this.obtenerEmpleadoPorId(p.id_residente);
      } else if (p.id_maestro) {
        this.selectedEmpleadoForKpi = this.obtenerEmpleadoPorId(p.id_maestro);
      } else {
        const albanil = this.obtenerEmpleadoPorId(p.id_albaniles?.[0]);
        if (albanil) {
          this.selectedEmpleadoForKpi = albanil;
        } else {
          this.selectedEmpleadoForKpi = this.empleados[0] || null;
        }
      }
    }
  }

  seleccionarEmpleadoForKpis(emp: any) {
    if (emp) {
      this.selectedEmpleadoForKpi = emp;
    }
  }

  getKPIs(id: number) {
    if (!id) return { asistencia: 0, eficiencia: 0, seguridad: 0 };
    // Generación matemática determinista para realismo de KPIs por empleado
    const asistencia = ((id * 17) % 21) + 80;  // 80 - 100%
    const eficiencia = ((id * 23) % 25) + 75;  // 75 - 100%
    const seguridad = ((id * 13) % 11) + 90;   // 90 - 100%
    return { asistencia, eficiencia, seguridad };
  }

  getKPIStatusText(id: number): string {
    if (!id) return '';
    const kpi = this.getKPIs(id);
    const avg = (kpi.asistencia + kpi.eficiencia + kpi.seguridad) / 3;
    if (avg >= 92) return 'Desempeño Sobresaliente - Altamente recomendado para incentivos y liderar nuevas cuadrillas.';
    if (avg >= 83) return 'Desempeño Óptimo - Cumple de manera constante con todos los objetivos y estándares de la constructora.';
    return 'Desempeño Regular - Requiere supervisión cercana para mejorar la eficiencia y puntualidad en obra.';
  }

}