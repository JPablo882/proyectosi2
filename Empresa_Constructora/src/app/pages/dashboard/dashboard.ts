import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  Router,
  RouterModule,
  RouterOutlet
} from '@angular/router';

import { ApiService } from '../../services/api';
import { forkJoin } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    RouterModule,
    RouterOutlet
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit {

  esAdminGeneral = false;
  nombreEmpresa = '';
  isDarkMode = false;

  showNotifications = false;
  notifications: any[] = [];
  proyectos: any[] = [];
  readNotificationIds: string[] = [];

  constructor(
    private apiService: ApiService,
    private router: Router
  ){}

  ngOnInit() {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'dark') {
      this.isDarkMode = true;
      document.body.classList.add('dark-mode');
    } else {
      this.isDarkMode = false;
      document.body.classList.remove('dark-mode');
    }

    const empresaDataStr = localStorage.getItem('empresa');
    if (empresaDataStr) {
      try {
        const empresaData = JSON.parse(empresaDataStr);
        this.nombreEmpresa = empresaData.nombre_empresa || '';
      } catch (e) {}
    }

    const usuarioStr = localStorage.getItem('usuario');
    if (usuarioStr) {
      try {
        const usuario = JSON.parse(usuarioStr);
        if (usuario && usuario.rol === 'Administrador') {
          this.esAdminGeneral = true;
          this.nombreEmpresa = 'Administrador General';
        }
      } catch (e) {
        console.error('Error parsing usuario from localStorage:', e);
      }
    }

    // Load read notifications from localStorage
    this.cargarReadNotificationIds();

    this.cargarNotificacionesReales();
  }

  cargarReadNotificationIds() {
    const readIdsStr = localStorage.getItem('proysi2_read_notification_ids');
    if (readIdsStr) {
      try {
        const parsed = JSON.parse(readIdsStr);
        this.readNotificationIds = Array.isArray(parsed) ? parsed : [];
      } catch (e) {
        this.readNotificationIds = [];
      }
    } else {
      this.readNotificationIds = [];
    }
  }

  cargarNotificacionesReales() {
    // Reload read IDs to keep read status in sync
    this.cargarReadNotificationIds();

    forkJoin({
      proyectos: this.apiService.obtenerProyectos(),
      avances: this.apiService.obtenerAvances(),
      movimientos: this.apiService.obtenerMovimientosFinancieros()
    }).subscribe({
      next: (res: any) => {
        this.proyectos = res.proyectos || [];
        const listaAvances = res.avances || [];
        const listaMovimientos = res.movimientos || [];

        const tempNotifications: any[] = [];

        // 1. Map progress updates (avances)
        listaAvances.forEach((av: any) => {
          const pName = this.obtenerNombreProyecto(av.id_proyecto);
          const id = `avance-${av.id_avance}`;
          tempNotifications.push({
            id: id,
            text: `Nuevo avance en ${pName}: ${av.titulo}`,
            time: this.formatearFecha(av.fecha_avance),
            unread: !this.readNotificationIds.includes(id),
            rawDate: av.fecha_avance ? new Date(av.fecha_avance) : new Date(0)
          });
        });

        // 2. Map completed income movements (payments)
        listaMovimientos
          .filter((m: any) => (m.tipo_movimiento || '').toLowerCase() === 'ingreso')
          .forEach((mov: any) => {
            const id = `pago-${mov.id_movimiento}`;
            const pName = mov.id_proyecto ? ` en ${this.obtenerNombreProyecto(mov.id_proyecto)}` : '';
            tempNotifications.push({
              id: id,
              text: `Pago de cuota registrado${pName}: ${Number(mov.monto).toLocaleString('es-BO', {minimumFractionDigits: 2})} Bs`,
              time: this.formatearFecha(mov.fecha),
              unread: !this.readNotificationIds.includes(id),
              rawDate: mov.fecha ? new Date(mov.fecha) : new Date(0)
            });
          });

        // Sort by date descending
        tempNotifications.sort((a, b) => b.rawDate.getTime() - a.rawDate.getTime());

        // Cap at 10 items
        this.notifications = tempNotifications.slice(0, 10);
      },
      error: (err) => {
        console.error('Error al cargar notificaciones reales:', err);
      }
    });
  }

  obtenerNombreProyecto(idProyecto: any): string {
    const p = this.proyectos.find(proj => proj.id_proyecto == idProyecto);
    return p ? p.nombre : `Proyecto #${idProyecto}`;
  }

  formatearFecha(fechaStr: string): string {
    if (!fechaStr) return 'Reciente';
    const d = new Date(fechaStr);
    if (isNaN(d.getTime())) return fechaStr;
    const dia = d.getDate().toString().padStart(2, '0');
    const mes = (d.getMonth() + 1).toString().padStart(2, '0');
    const anio = d.getFullYear();
    return `${dia}/${mes}/${anio}`;
  }

  toggleNotifications() {
    this.showNotifications = !this.showNotifications;
    if (this.showNotifications) {
      // Reload notifications when opening to get the latest database changes
      this.cargarNotificacionesReales();
    }
  }

  marcarLeidas() {
    this.notifications.forEach(n => {
      n.unread = false;
      if (!this.readNotificationIds.includes(n.id)) {
        this.readNotificationIds.push(n.id);
      }
    });
    localStorage.setItem('proysi2_read_notification_ids', JSON.stringify(this.readNotificationIds));
  }

  get unreadCount() {
    return this.notifications.filter(n => n.unread).length;
  }

  toggleTheme() {
    this.isDarkMode = !this.isDarkMode;
    if (this.isDarkMode) {
      document.body.classList.add('dark-mode');
      localStorage.setItem('theme', 'dark');
    } else {
      document.body.classList.remove('dark-mode');
      localStorage.setItem('theme', 'light');
    }
  }

  // ===== CERRAR SESION =====

  cerrarSesion(){
    localStorage.removeItem('empresa');
    localStorage.removeItem('usuario');
    this.router.navigate(['/login']);
  }

}