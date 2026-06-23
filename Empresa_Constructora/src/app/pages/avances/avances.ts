import {
  Component,
  OnInit,
  ChangeDetectorRef
} from '@angular/core';

import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-avances',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './avances.html',
  styleUrl: './avances.scss'
})
export class AvancesComponent implements OnInit {

  proyectos: any[] = [];
  avances: any[] = [];
  urlMapa: SafeResourceUrl | null = null;

  // Propiedades para fotos y planos del proyecto
  fotosProyecto: string[] = [];
  planosProyecto: any[] = [];
  fotoModalUrl: string | null = null;

  avance = {
    id_proyecto: '',
    titulo: '',
    descripcion: '',
    responsable: '',
    porcentaje_avance: 0
  };

  constructor(
    private api: ApiService,
    private cd: ChangeDetectorRef,
    private sanitizer: DomSanitizer
  ){}

  ngOnInit(): void {

    this.cargarProyectos();
    this.cargarAvances();
    this.actualizarMapa();

  }

  actualizarMapa(): void {
    this.cargarArchivosProyecto();

    if (!this.avance.id_proyecto) {
      this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl('https://maps.google.com/maps?q=Santa%20Cruz%20de%20la%20Sierra,%20Bolivia&z=13&output=embed');
      return;
    }

    const proj = this.proyectos.find(p => p.id_proyecto == this.avance.id_proyecto);
    if (!proj || !proj.ubicacion) {
      this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl('https://maps.google.com/maps?q=Santa%20Cruz%20de%20la%20Sierra,%20Bolivia&z=13&output=embed');
      return;
    }

    const ubicacion = proj.ubicacion.trim();

    // 1. Intentar extraer coordenadas directas (latitud, longitud)
    const coordRegex = /(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)/;
    const match = ubicacion.match(coordRegex);

    if (match) {
      const lat = match[1];
      const lon = match[2];
      const url = `https://maps.google.com/maps?q=${lat},${lon}&z=16&output=embed`;
      this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl(url);
    } else if (ubicacion.toLowerCase().startsWith('http://') || ubicacion.toLowerCase().startsWith('https://')) {
      // 2. Si es un enlace de Google Maps, buscar si tiene coordenadas empotradas (ej. /@lat,lon o q=lat,lon)
      const urlCoordRegex = /@(-?\d+\.\d+),(-?\d+\.\d+)/;
      const urlMatch = ubicacion.match(urlCoordRegex);
      if (urlMatch) {
        const lat = urlMatch[1];
        const lon = urlMatch[2];
        const url = `https://maps.google.com/maps?q=${lat},${lon}&z=16&output=embed`;
        this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl(url);
      } else {
        // Fallback a buscar por nombre de proyecto + Santa Cruz
        const query = encodeURIComponent(proj.nombre + ', Santa Cruz, Bolivia');
        const url = `https://maps.google.com/maps?q=${query}&z=15&output=embed`;
        this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl(url);
      }
    } else {
      // 3. Dirección de texto normal (ej. Barrio Agricola el Dorado)
      const query = encodeURIComponent(ubicacion);
      const url = `https://maps.google.com/maps?q=${query}&z=15&output=embed`;
      this.urlMapa = this.sanitizer.bypassSecurityTrustResourceUrl(url);
    }
  }

  cargarProyectos(){

    this.api.obtenerProyectos()
      .subscribe({

        next: (resp:any) => {

          console.log('PROYECTOS:', resp);

          this.proyectos = [...resp];

          this.actualizarMapa();

          this.cd.detectChanges();

        },

        error: (err) => {

          console.error(err);

        }

      });

  }

  cargarAvances(){

    this.api.obtenerAvances()
      .subscribe({

        next: (resp:any) => {

          console.log('AVANCES:', resp);

          this.avances = [...resp];

          this.cd.detectChanges();

        },

        error: (err) => {

          console.error('ERROR AVANCES:', err);

        }

      });

  }

  registrarAvance(){

    this.api.crearAvance(this.avance)
      .subscribe({

        next: () => {

          alert('Avance registrado');

          this.avance = {
            id_proyecto: '',
            titulo: '',
            descripcion: '',
            responsable: '',
            porcentaje_avance: 0
          };

          this.cargarAvances();

        },

        error: (err) => {

          console.error(err);

        }

      });

  }

  obtenerNombreProyecto(idProyecto: any): string {
    const p = this.proyectos.find(proj => proj.id_proyecto == idProyecto);
    return p ? p.nombre : 'Proyecto #' + idProyecto;
  }

  cargarArchivosProyecto() {
    if (!this.avance.id_proyecto) {
      this.fotosProyecto = [];
      this.planosProyecto = [];
      return;
    }

    this.api.obtenerDetalleProyectoCliente(Number(this.avance.id_proyecto))
      .subscribe({
        next: (resp: any) => {
          console.log('Archivos de proyecto cargados:', resp);
          this.fotosProyecto = resp.fotos || [];
          this.planosProyecto = resp.documentos || [];
          this.cd.detectChanges();
        },
        error: (err) => {
          console.error('Error al cargar archivos de proyecto:', err);
          this.fotosProyecto = [];
          this.planosProyecto = [];
        }
      });
  }

  completarRutaUrl(ruta: string): string {
    if (!ruta) return '';
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }
    const cleanRuta = ruta.startsWith('/') ? ruta.substring(1) : ruta;
    return `http://127.0.0.1:8000/${cleanRuta}`;
  }

  verFotoCompleta(url: string) {
    this.fotoModalUrl = url;
  }

  cerrarFotoModal() {
    this.fotoModalUrl = null;
  }
}