import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-recuperar-password',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    FormsModule
  ],
  templateUrl: './recuperar-password.html',
  styleUrl: './recuperar-password.scss'
})
export class RecuperarPasswordComponent {

  email = '';

  constructor(
    private apiService: ApiService,
    private router: Router
  ) {}

  recuperarPassword() {

    const data = {
      email: this.email
    };

    this.apiService.solicitarRecuperacion(data)
      .subscribe({

        next: (resp: any) => {

          console.log(resp);

          alert('Correo de recuperación enviado');

          if(resp.reset_link){

            window.location.href = resp.reset_link;

          }

        },

        error: (err: any) => {

          console.error(err);

          alert('No se pudo recuperar la contraseña');

        }

      });

  }

}