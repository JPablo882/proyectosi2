import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';

import { BaseChartDirective } from 'ng2-charts';
import { ApiService } from '../../services/api';
import { forkJoin } from 'rxjs';

@Component({
  selector: 'app-dashboard-home',
  standalone: true,
  imports: [
    CommonModule,
    BaseChartDirective
  ],
  templateUrl: './dashboard-home.html',
  styleUrl: './dashboard-home.scss'
})
export class DashboardHomeComponent implements OnInit {

  nombreEmpresa = '';
  cantClientes = 0;
  cantObras = 0;
  totalVentas = 0; // Ganancias
  totalPerdidas = 0; // Compras
  valorInventario = 0;
  balanceNeto = 0;

  ultimasObras: any[] = [];
  materialesStock: any[] = [];

  // Line Chart (Ganancias vs Pérdidas)
  lineChartData: any = {
    labels: ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'],
    datasets: [
      {
        data: [0, 0, 0, 0, 0, 0],
        label: 'Ganancias (Ventas)',
        borderColor: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.05)',
        fill: true,
        tension: 0.4
      },
      {
        data: [0, 0, 0, 0, 0, 0],
        label: 'Pérdidas (Compras)',
        borderColor: '#ef4444',
        backgroundColor: 'rgba(239, 68, 68, 0.05)',
        fill: true,
        tension: 0.4
      }
    ]
  };

  lineChartType: any = 'line';

  // Pie Chart (Proyectos por Estado)
  pieChartData: any = {
    labels: ['En construcción', 'Planificación', 'Finalizados'],
    datasets: [
      {
        data: [0, 0, 0],
        backgroundColor: ['#3b82f6', '#f59e0b', '#10b981']
      }
    ]
  };

  pieChartType: any = 'pie';

  // Chart options to style them beautifully
  lineChartOptions: any = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          color: '#334155',
          font: { weight: '600', family: 'Inter', size: 12 }
        }
      }
    },
    scales: {
      x: {
        grid: { display: false },
        ticks: { color: '#64748b', font: { family: 'Inter', size: 11 } }
      },
      y: {
        grid: { color: '#f1f5f9' },
        ticks: { color: '#64748b', font: { family: 'Inter', size: 11 } }
      }
    }
  };

  pieChartOptions: any = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          color: '#334155',
          font: { weight: '600', family: 'Inter', size: 12 },
          padding: 15
        }
      }
    }
  };

  constructor(
    private apiService: ApiService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit() {
    const empresaDataStr = localStorage.getItem('empresa');
    if (empresaDataStr) {
      try {
        const empresaData = JSON.parse(empresaDataStr);
        this.nombreEmpresa = empresaData.nombre_empresa || empresaData.nombre || '';
      } catch (e) {}
    }
    this.cargarMetricas();
  }

  cargarMetricas() {
    forkJoin({
      clientes: this.apiService.obtenerClientes(),
      proyectos: this.apiService.obtenerProyectos(),
      movimientos: this.apiService.obtenerMovimientosFinancieros(),
      materiales: this.apiService.obtenerMateriales()
    }).subscribe({
      next: (res: any) => {
        // 1. Clientes
        this.cantClientes = res.clientes ? res.clientes.length : 0;

        // 2. Proyectos
        const listaProyectos = res.proyectos || [];
        this.cantObras = listaProyectos.filter((p: any) => (p.estado || p.estado_proyecto) !== 'Finalizado').length;
        
        // Filter: only show projects in specified active/completed states, exclude 'Pendiente' completely
        const validStates = ['en construcción', 'en planificación', 'planificación', 'en ejecución', 'finalizado', 'finalizados'];
        const filteredProyectos = listaProyectos.filter((p: any) => {
          const st = (p.estado || p.estado_proyecto || '').toLowerCase();
          return validStates.includes(st);
        });

        // Sort by id_proyecto descending (most recent first)
        this.ultimasObras = filteredProyectos
          .sort((a: any, b: any) => Number(b.id_proyecto || 0) - Number(a.id_proyecto || 0))
          .slice(0, 5);

        const construccion = listaProyectos.filter((p: any) => (p.estado === 'En construcción' || p.estado_proyecto === 'En construcción')).length;
        const planificacion = listaProyectos.filter((p: any) => (p.estado === 'En planificación' || p.estado_proyecto === 'En planificación' || p.estado === 'Planificación')).length;
        const finalizado = listaProyectos.filter((p: any) => (p.estado === 'Finalizado' || p.estado_proyecto === 'Finalizado')).length;

        this.pieChartData = {
          labels: ['En construcción', 'Planificación', 'Finalizados'],
          datasets: [{
            data: [construccion, planificacion, finalizado],
            backgroundColor: ['#3b82f6', '#f59e0b', '#10b981']
          }]
        };

        // 3. Movimientos Financieros (Ganancias & Pérdidas)
        const listaMovimientos = res.movimientos || [];
        const ingresos = listaMovimientos.filter((m: any) => (m.tipo_movimiento || '').toLowerCase() === 'ingreso');
        const egresos = listaMovimientos.filter((m: any) => (m.tipo_movimiento || '').toLowerCase() === 'egreso');

        // Ganancias Totales
        this.totalVentas = ingresos.reduce((acc: number, curr: any) => acc + Number(curr.monto || 0), 0);

        // Pérdidas Totales
        this.totalPerdidas = egresos.reduce((acc: number, curr: any) => acc + Number(curr.monto || 0), 0);

        // Balance
        this.balanceNeto = this.totalVentas - this.totalPerdidas;

        // 4. Inventario
        const listaMateriales = res.materiales || [];
        this.materialesStock = listaMateriales.slice(0, 5);
        this.valorInventario = listaMateriales.reduce((acc: number, curr: any) => acc + (Number(curr.stock || 0) * Number(curr.precio || 0)), 0);

        // 5. Last 6 Months Chart Labels and aggregation
        const nombresMeses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        const hoy = new Date();
        const ultimos6MesesNombres: string[] = [];
        const gananciasPorMes = [0, 0, 0, 0, 0, 0];
        const perdidasPorMes = [0, 0, 0, 0, 0, 0];

        for (let i = 5; i >= 0; i--) {
          const d = new Date(hoy.getFullYear(), hoy.getMonth() - i, 1);
          ultimos6MesesNombres.push(nombresMeses[d.getMonth()]);
        }

        const getMonthIndex = (fechaStr: string): number => {
          if (!fechaStr) return -1;
          const d = new Date(fechaStr);
          if (isNaN(d.getTime())) return -1;
          
          const diffMonths = (hoy.getFullYear() - d.getFullYear()) * 12 + (hoy.getMonth() - d.getMonth());
          if (diffMonths >= 0 && diffMonths < 6) {
            return 5 - diffMonths;
          }
          return -1;
        };

        ingresos.forEach((v: any) => {
          const idx = getMonthIndex(v.fecha);
          if (idx !== -1) {
            gananciasPorMes[idx] += Number(v.monto || 0);
          }
        });

        egresos.forEach((c: any) => {
          const idx = getMonthIndex(c.fecha);
          if (idx !== -1) {
            perdidasPorMes[idx] += Number(c.monto || 0);
          }
        });

        // Fallbacks for display
        const hayGanancias = gananciasPorMes.some(v => v > 0);
        if (!hayGanancias && this.totalVentas > 0) {
          gananciasPorMes[5] = this.totalVentas;
        }
        const hayPerdidas = perdidasPorMes.some(v => v > 0);
        if (!hayPerdidas && this.totalPerdidas > 0) {
          perdidasPorMes[5] = this.totalPerdidas;
        }

        this.lineChartData = {
          labels: ultimos6MesesNombres,
          datasets: [
            {
              data: gananciasPorMes,
              label: 'Ganancias (Ingresos)',
              borderColor: '#10b981',
              backgroundColor: 'rgba(16, 185, 129, 0.05)',
              fill: true,
              tension: 0.4
            },
            {
              data: perdidasPorMes,
              label: 'Pérdidas (Egresos)',
              borderColor: '#ef4444',
              backgroundColor: 'rgba(239, 68, 68, 0.05)',
              fill: true,
              tension: 0.4
            }
          ]
        };

        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Error al cargar métricas combinadas del dashboard:', err);
      }
    });
  }
}