import {
  Component,
  OnInit,
  ChangeDetectorRef
} from '@angular/core';

import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-inventario',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './inventario.html',
  styleUrls: ['./inventario.scss']
})
export class InventarioComponent implements OnInit {

  materiales: any[] = [];
  materialesFiltrados: any[] = [];
  proyectos: any[] = [];

  filtro = '';

  stockCritico = 0;
  stockBajo = 0;

  // Modal properties
  isModalOpen = false;
  proyectoSeleccionadoId: any = '';
  materialSeleccionadoId: any = '';
  cantidadAOcupar: number | null = null;
  stockDisponible: number | null = null;

  constructor(
    private api: ApiService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {

    this.cargarMateriales();

  }

  cargarMateriales(): void {

    this.api.obtenerMateriales()
      .subscribe({

        next: (resp: any) => {

          console.log('RESPUESTA MATERIAL:', resp);

          this.materiales = resp || [];

          this.materialesFiltrados = [...this.materiales];

          this.stockCritico =
            this.materiales.filter(m => m.stock <= 30).length;

          this.stockBajo =
            this.materiales.filter(
              m => m.stock > 30 && m.stock < 50
            ).length;

          this.cdr.detectChanges();

        },

        error: (err) => {

          console.error('ERROR MATERIALES', err);

        }

      });

  }

  filtrarMateriales(): void {

    this.materialesFiltrados =
      this.materiales.filter(material =>
        material.nombre
          .toLowerCase()
          .includes(this.filtro.toLowerCase())
      );

  }

  obtenerEstado(stock: number): string {

    if (stock <= 30) {
      return 'Crítico';
    }

    if (stock < 50) {
      return 'Bajo';
    }

    return 'Normal';

  }

  // --- METODOS DEL MODAL (OCUPAR MATERIAL) ---
  abrirModal(): void {
    this.isModalOpen = true;
    this.proyectoSeleccionadoId = '';
    this.materialSeleccionadoId = '';
    this.cantidadAOcupar = null;
    this.stockDisponible = null;

    // Cargar proyectos para el dropdown
    this.api.obtenerProyectos().subscribe({
      next: (resp: any) => {
        this.proyectos = resp || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Error al cargar proyectos:', err)
    });
  }

  cerrarModal(): void {
    this.isModalOpen = false;
  }

  actualizarStockDisponible(): void {
    const mat = this.materiales.find(m => m.id_material == this.materialSeleccionadoId);
    this.stockDisponible = mat ? mat.stock : null;
  }

  confirmarOcuparMaterial(): void {
    if (!this.proyectoSeleccionadoId || !this.materialSeleccionadoId || !this.cantidadAOcupar || this.cantidadAOcupar <= 0) {
      alert('Por favor complete todos los datos.');
      return;
    }

    if (this.stockDisponible !== null && this.cantidadAOcupar > this.stockDisponible) {
      alert('La cantidad a ocupar supera el stock disponible.');
      return;
    }

    const payload = {
      id_material: Number(this.materialSeleccionadoId),
      id_proyecto: Number(this.proyectoSeleccionadoId),
      cantidad: this.cantidadAOcupar
    };

    this.api.ocuparMaterial(payload).subscribe({
      next: (res: any) => {
        alert(res.mensaje || 'Material descontado correctamente.');
        this.isModalOpen = false;
        this.cargarMateriales(); // Recargar el inventario
      },
      error: (err: any) => {
        alert('Error al descontar material: ' + (err.error?.detail || err.message));
      }
    });
  }

}