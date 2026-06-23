import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpClientModule } from '@angular/common/http';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-registro-empresa',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    FormsModule,
    HttpClientModule
  ],
  templateUrl: './registro-empresa.html',
  styleUrl: './registro-empresa.scss'
})
export class RegistroEmpresaComponent {

  paso = 1;

  empresa = {
    nombre_empresa: '',
    email_empresa: '',
    telefono: '',
    direccion: '',

    nombre_admin: '',
    email_admin: '',
    password: '',
    confirmar_password: ''
  };

  constructor(private apiService: ApiService) {}

  siguientePaso() {

    this.paso = 2;

  }

  volverPaso1() {

    this.paso = 1;

  }

  registrarEmpresa() {

    if(this.empresa.password !== this.empresa.confirmar_password){

      alert('Las contraseñas no coinciden');
      return;

    }

    const data = {

  nombre: this.empresa.nombre_empresa,
  nit: '123456',

  telefono: this.empresa.telefono,

  email: this.empresa.email_empresa,

  direccion: this.empresa.direccion,

  contrasena_empresa: this.empresa.password,

  admin_usuario: this.empresa.nombre_admin,

  admin_nombres: this.empresa.nombre_admin,

  admin_apellido: 'Administrador',

  admin_email: this.empresa.email_admin,

  admin_contrasena: this.empresa.password

};

    console.log(data);

    this.apiService.registrarEmpresa(data)
      .subscribe({

        next: (resp) => {

          console.log(resp);

          alert('Empresa registrada correctamente');

        },

        error: (err) => {

          console.error(err);

          alert('Error al registrar empresa');

        }

      });

  }

}