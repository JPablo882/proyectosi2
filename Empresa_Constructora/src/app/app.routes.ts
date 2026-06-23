import { Routes } from '@angular/router';

import { ClientesComponent } from './pages/clientes/clientes';
import { RegistroEmpresaComponent } from './pages/registro-empresa/registro-empresa';
import { LoginComponent } from './pages/login/login';
import { DashboardComponent } from './pages/dashboard/dashboard';
import { RecuperarPasswordComponent } from './pages/recuperar-password/recuperar-password';
import { ResetPasswordComponent } from './pages/reset-password/reset-password';
import { DashboardHomeComponent } from './pages/dashboard-home/dashboard-home';
import { ProyectosComponent } from './pages/proyectos/proyectos';
import { ChatbotComponent } from './pages/chatbot/chatbot';
import { RrhhComponent } from './pages/rrhh/rrhh';
import { ComprasComponent } from './pages/compras/compras';
import { ReportesComponent } from './pages/reportes/reportes';
import { PresupuestoComponent } from './pages/presupuesto/presupuesto';
import { InventarioComponent } from './pages/inventario/inventario';
import { AvancesComponent } from './pages/avances/avances';
import { DocumentosComponent } from './pages/documentos/documentos';
import { LoginAdminComponent } from './pages/login-admin/login-admin';
import { ActivosComponent } from './pages/activos/activos';
import { PerfilEmpresaComponent } from './pages/perfil-empresa/perfil-empresa';
export const routes: Routes = [

  {
    path: '',
    loadComponent: () =>
      import('./home/home')
        .then(m => m.HomeComponent)
  },

  {
    path: 'registro-empresa',
    component: RegistroEmpresaComponent
  },

  {
    path: 'login',
    component: LoginComponent
  },

  {
    path: 'login-admin',
    component: LoginAdminComponent
  },

  {
    path: 'dashboard',
    component: DashboardComponent,

    children: [

      {
        path: '',
        component: DashboardHomeComponent
      },

      {
        path: 'clientes',
        component: ClientesComponent
      },
      {
  path: 'proyectos',
  component: ProyectosComponent
},
{
  path: 'avances',
  component: AvancesComponent
},
{
  path: 'chatbot',
  component: ChatbotComponent
},
{
  path: 'rrhh',
  component: RrhhComponent
},
{
  path: 'compras',
  component: ComprasComponent
},
{
  path: 'reportes',
  component: ReportesComponent
},
{
  path: 'presupuesto',
  component: PresupuestoComponent
},
{
  path: 'inventario',
  component: InventarioComponent
},
{
  path: 'documentos',
  component: DocumentosComponent
},
{
  path: 'activos',
  component: ActivosComponent
},
{
  path: 'perfil',
  component: PerfilEmpresaComponent
}



    ]
  },

  {
    path: 'recuperar-password',
    component: RecuperarPasswordComponent
  },

  {
    path: 'reset-password',
    component: ResetPasswordComponent
  },
  

];