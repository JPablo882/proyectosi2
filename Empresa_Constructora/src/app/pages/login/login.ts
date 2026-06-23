import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    FormsModule
  ],
  templateUrl: './login.html',
  styleUrl: './login.scss'
})
export class LoginComponent {

  loginData = {
    email: '',
    password: ''
  };

  constructor(
    private apiService: ApiService,
    private router: Router
  ) {}

  iniciarSesion() {

    const body = {

      email: this.loginData.email,

      contrasena: this.loginData.password

    };

    console.log(body);

    this.apiService.loginEmpresa(body)
      .subscribe({

        next: (resp: any) => {

          console.log(resp);

          alert('Login exitoso');

          localStorage.removeItem('usuario');
          localStorage.setItem(
            'empresa',
            JSON.stringify(resp)
          );

          this.router.navigate(['/dashboard']);

        },

        error: (err: any) => {

          console.error(err);

          console.log(err.error);

          alert(JSON.stringify(err.error));

        }

      });

  }

}