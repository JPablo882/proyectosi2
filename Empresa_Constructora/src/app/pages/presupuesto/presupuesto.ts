import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-presupuesto',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './presupuesto.html',
  styleUrl: './presupuesto.scss'
})
export class PresupuestoComponent {

  presupuesto = {

    id_proyecto: null,

    area_m2: 0,
    precio_m2_usd: 25,
    tipo_cambio: 6.96,

    porcentaje_indirectos: 10,
    porcentaje_utilidad: 15,
    porcentaje_impuestos: 3,

    guardar_en_bd: true

  };

  resultado:any = null;

  constructor(
    private api: ApiService
  ){}

  calcularPresupuesto(){

    this.api.calcularPresupuesto(this.presupuesto)
    .subscribe({

      next: (resp:any) => {

        console.log(resp);

        this.resultado = resp;

      },

      error: (err) => {

        console.log(err);

        alert('Error al calcular presupuesto');

      }

    });

  }

}