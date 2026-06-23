import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-documentos',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './documentos.html',
  styleUrl: './documentos.scss'
})
export class DocumentosComponent implements OnInit {

  documentos: any[] = [];

  proyectos: any[] = [];

  filtro = '';

  archivoSeleccionado!: File;

  documento = {

    id_proyecto: '',

    nombre: '',

    tipo: '',

    tamano: '',

    formato: ''

  };

  constructor(private api: ApiService){}

  ngOnInit(): void {

    this.cargarDocumentos();

    this.cargarProyectos();

  }

  cargarDocumentos(){

    this.api.obtenerDocumentos()
      .subscribe((resp:any)=>{

        console.log('DOCUMENTOS:', resp);

        this.documentos = resp;

      });

  }

  cargarProyectos(){

    this.api.obtenerProyectos()
      .subscribe((resp:any)=>{

        console.log('PROYECTOS:', resp);

        this.proyectos = resp;

      });

  }

  seleccionarArchivo(event:any){

    this.archivoSeleccionado = event.target.files[0];

    console.log('ARCHIVO:', this.archivoSeleccionado);

  }

  registrarDocumento(){

    if(!this.archivoSeleccionado){

      alert('Seleccione un archivo');

      return;

    }

    if(!this.documento.id_proyecto){

      alert('Seleccione un proyecto');

      return;

    }

    const formData = new FormData();

    formData.append(
      'archivo',
      this.archivoSeleccionado
    );

    formData.append(
      'id_proyecto',
      this.documento.id_proyecto
    );

    formData.append(
      'nombre',
      this.documento.nombre
    );

    formData.append(
      'tipo',
      this.documento.tipo
    );

    formData.append(
      'tamano',
      this.documento.tamano
    );

    formData.append(
      'formato',
      this.documento.formato
    );

    this.api.subirDocumento(formData)
      .subscribe({

        next: (resp)=>{

          console.log(resp);

          alert('Documento subido correctamente');

          this.documento = {

            id_proyecto: '',

            nombre: '',

            tipo: '',

            tamano: '',

            formato: ''

          };

          this.cargarDocumentos();

        },

        error: (err)=>{

          console.error(err);

          alert('Error al subir documento');

        }

      });

  }

  eliminarDocumento(id:number){

    if(!confirm('¿Eliminar documento?')){
      return;
    }

    this.api.eliminarDocumento(id)
      .subscribe(()=>{

        this.cargarDocumentos();

      });

  }

  obtenerNombreProyecto(idProyecto: any): string {
    const p = this.proyectos.find(proj => proj.id_proyecto == idProyecto);
    return p ? p.nombre : 'Proyecto #' + idProyecto;
  }

  get documentosFiltrados(){

    return this.documentos.filter(doc =>

      doc.nombre
        .toLowerCase()
        .includes(this.filtro.toLowerCase())

    );

  }

}