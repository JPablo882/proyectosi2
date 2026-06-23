import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-perfil-empresa',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './perfil-empresa.html',
  styleUrl: './perfil-empresa.scss'
})
export class PerfilEmpresaComponent implements OnInit {

  empresa: any = {};
  adminName = '';
  adminEmail = '';
  logoUrl: string | null = null;

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    const empresaStr = localStorage.getItem('empresa');
    if (empresaStr) {
      try {
        const data = JSON.parse(empresaStr);
        this.empresa = data;
        
        // Load saved logo from localStorage
        const savedLogo = localStorage.getItem('empresa_logo_' + this.empresa.id_empresa);
        if (savedLogo) {
          this.logoUrl = savedLogo;
        }
        
        // Sometimes backend returns admin data inside 'usuario' or similar
        // We will try to extract if there's any admin info directly or via another local storage key
        const userStr = localStorage.getItem('usuario');
        if (userStr) {
          const userData = JSON.parse(userStr);
          this.adminName = userData.nombre_completo || userData.nombre || 'Administrador';
          this.adminEmail = userData.email || userData.correo || 'N/A';
        }
      } catch (e) {
        console.error('Error parsing empresa data', e);
      }
    }
  }

  triggerFileInput() {
    const fileInput = document.getElementById('logoFileInput') as HTMLInputElement;
    if (fileInput) {
      fileInput.click();
    }
  }

  onFileSelected(event: any) {
    const file: File = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e: any) => {
        this.logoUrl = e.target.result;
        // Save to localStorage so it persists locally
        if (this.empresa && this.empresa.id_empresa) {
          localStorage.setItem('empresa_logo_' + this.empresa.id_empresa, this.logoUrl as string);
          
          // Also save it to backend!
          this.apiService.actualizarLogoEmpresa(this.empresa.id_empresa, this.logoUrl as string)
            .subscribe({
              next: (res) => console.log('Logo guardado en backend', res),
              error: (err) => console.error('Error guardando logo', err)
            });
        }
      };
      reader.readAsDataURL(file);
    }
  }

  isEditingDescription = false;
  tempDescription = '';

  editDescription() {
    this.isEditingDescription = true;
    this.tempDescription = this.empresa?.descripcion || '';
  }

  saveDescription() {
    if (!this.empresa) this.empresa = {};
    this.empresa.descripcion = this.tempDescription;
    this.isEditingDescription = false;
    this.saveToLocalStorage();
  }

  deleteDescription() {
    if (this.empresa) {
      this.empresa.descripcion = '';
      this.saveToLocalStorage();
    }
    this.isEditingDescription = false;
  }

  cancelEdit() {
    this.isEditingDescription = false;
  }

  saveToLocalStorage() {
    if (this.empresa) {
      localStorage.setItem('empresa', JSON.stringify(this.empresa));
    }
  }

  showFullImage = false;

  openFullImage() {
    this.showFullImage = true;
  }

  closeFullImage() {
    this.showFullImage = false;
  }

}
