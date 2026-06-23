import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-login-admin',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    FormsModule
  ],
  templateUrl: './login-admin.html',
  styleUrl: './login-admin.scss'
})
export class LoginAdminComponent {

  loginData = {
    identificador: '',
    password: ''
  };

  constructor(
    private apiService: ApiService,
    private router: Router
  ) {}

  iniciarSesionAdmin() {
    if (!this.loginData.identificador || !this.loginData.password) {
      alert('Por favor complete todos los campos.');
      return;
    }

    const body = {
      identificador: this.loginData.identificador,
      contrasena: this.loginData.password
    };

    console.log('Iniciando sesión como admin general con:', body);

    this.apiService.loginUsuario(body, '1')
      .subscribe({
        next: (resp: any) => {
          console.log('Login exitoso:', resp);
          alert('Login de Administrador exitoso');

          // Almacenar datos del usuario
          localStorage.setItem(
            'usuario',
            JSON.stringify(resp)
          );

          // Almacenar estructura de empresa compatible para evitar incompatibilidades
          localStorage.setItem(
            'empresa',
            JSON.stringify({
              id_empresa: resp.id_empresa,
              nombre_empresa: resp.usuario,
              email: resp.email,
              id_usuario_admin: resp.id_usuario
            })
          );

          this.router.navigate(['/dashboard']);
        },
        error: (err: any) => {
          console.error('Error de inicio de sesión:', err);
          const errorMsg = err.error?.detail || 'Credenciales incorrectas o empresa no encontrada.';
          alert('Error: ' + errorMsg);
        }
      });
  }

}
