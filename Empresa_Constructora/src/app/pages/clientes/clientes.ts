import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ChangeDetectorRef } from '@angular/core';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-clientes',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './clientes.html',
  styleUrl: './clientes.scss'
})
export class ClientesComponent implements OnInit {

  clientes: any[] = [];

  constructor(
  private api: ApiService,
  private cd: ChangeDetectorRef
){}

  ngOnInit(): void {

    this.cargarClientes();

  }

  cargarClientes(){

    this.api.obtenerClientes()
    .subscribe({

      next: (resp:any) => {
        console.log(resp);

        this.clientes = resp.clientes || resp;
        this.cd.detectChanges();

      },

      error: (err) => {

        console.log(err);

      }

    });

  }
  eliminarCliente(id: number){

  const confirmar = confirm(
    '¿Deseas eliminar este cliente?'
  );

  if(!confirmar) return;

  this.api.eliminarCliente(id)
  .subscribe({

    next: () => {

      alert('Cliente eliminado');

      this.cargarClientes();

    },

    error: (err) => {

      console.log(err);

      alert('Error al eliminar');

    }

  });

}
  

}