import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-reset-password',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    FormsModule
  ],
  templateUrl: './reset-password.html',
  styleUrl: './reset-password.scss'
})
export class ResetPasswordComponent {

  nuevaPassword = '';

  confirmarPassword = '';
constructor(
  private router: Router
) {}
  cambiarPassword(){

    if(
      this.nuevaPassword !==
      this.confirmarPassword
    ){

      alert('Las contraseñas no coinciden');

      return;

    }

    alert('Contraseña actualizada');


    this.router.navigate(['/login']);

  }

}