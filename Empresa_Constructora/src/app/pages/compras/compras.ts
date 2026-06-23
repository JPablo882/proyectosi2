import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api';

@Component({
  selector: 'app-compras',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './compras.html',
  styleUrl: './compras.scss'
})
export class ComprasComponent implements OnInit {

  proveedor = {
    nombre: '',
    contacto: ''
  };

  compra = {
    id_proveedor: '',
    fecha: '',
    total: 0,
    estado: 'Pendiente'
  };

  detalle = {
    id_compra: '',
    id_material: '',
    cantidad: 0,
    precio: 0
  };

  material = {
    nombre: '',
    precio: 0,
    stock: 0
  };

  proveedores: any[] = [];
  compras: any[] = [];
  materiales: any[] = [];
  detallesCompra: any[] = [];

  constructor(private api: ApiService){}

  ngOnInit(): void {
    this.cargarProveedores();
    this.cargarCompras();
    this.cargarMateriales();
    this.cargarDetallesCompra();
  }

  cargarProveedores(){
    this.api.obtenerProveedores().subscribe((resp:any)=>{
      this.proveedores = resp || [];
    });
  }

  cargarCompras(){
    this.api.obtenerCompras().subscribe((resp:any)=>{
      this.compras = resp || [];
    });
  }

  cargarMateriales(){
    this.api.obtenerMateriales().subscribe((resp:any)=>{
      this.materiales = resp || [];
    });
  }

  cargarDetallesCompra(){
    this.api.obtenerDetallesCompra().subscribe((resp:any)=>{
      this.detallesCompra = resp || [];
    });
  }

  registrarProveedor(){
    if (!this.proveedor.nombre) return;
    this.api.crearProveedor(this.proveedor).subscribe(()=>{
      alert('Proveedor registrado exitosamente.');
      this.proveedor = { nombre: '', contacto: '' };
      this.cargarProveedores();
    });
  }

  registrarCompra(){
    if (!this.compra.id_proveedor || !this.compra.total) {
      alert('Por favor selecciona un proveedor y define el total.');
      return;
    }
    const payload = {
      ...this.compra,
      estado: 'Pendiente' // Asegurar que entre en el flujo de aprobación
    };
    this.api.crearCompra(payload).subscribe(()=>{
      alert('Orden de compra registrada como PENDIENTE de aprobación.');
      this.cargarCompras();
    });
  }

  registrarDetalleCompra(){
    if (!this.detalle.id_compra || !this.detalle.id_material || !this.detalle.cantidad) {
      alert('Por favor selecciona la compra, el material e ingresa la cantidad.');
      return;
    }
    this.api.crearDetalleCompra(this.detalle).subscribe(()=>{
      alert('Línea de detalle agregada exitosamente.');
      this.cargarDetallesCompra();
    });
  }

  registrarMaterial(){
    if (!this.material.nombre) return;
    this.api.crearMaterial(this.material).subscribe(()=>{
      alert('Material registrado.');
      this.material = { nombre: '', precio: 0, stock: 0 };
      this.cargarMateriales();
    });
  }

  // --- FLUJO DE APROBACIÓN EN CALIENTE ---
  aprobarCompra(id: number) {
    if (confirm('¿Está seguro de APROBAR esta orden de compra? Esto generará un movimiento de egreso en el flujo de caja.')) {
      this.api.aprobarCompra(id).subscribe({
        next: () => {
          alert('Orden de Compra aprobada con éxito. Egreso financiero registrado.');
          this.cargarCompras();
        },
        error: (err) => alert('Error al aprobar: ' + err.error?.detail || err.message)
      });
    }
  }

  rechazarCompra(id: number) {
    if (confirm('¿Está seguro de RECHAZAR esta orden de compra?')) {
      this.api.rechazarCompra(id).subscribe({
        next: () => {
          alert('Orden de Compra rechazada.');
          this.cargarCompras();
        },
        error: (err) => alert('Error al rechazar: ' + err.error?.detail || err.message)
      });
    }
  }

  obtenerNombreProveedor(idProveedor: any): string {
    const p = this.proveedores.find(prov => prov.id_proveedor == idProveedor);
    return p ? p.nombre : `Proveedor #${idProveedor}`;
  }

  // --- GENERACIÓN DE PDF MEMBRETADO ---
  generarPdfOrden(compra: any) {
    const proveedorNombre = this.obtenerNombreProveedor(compra.id_proveedor);
    const lineas = this.detallesCompra.filter(d => d.id_compra == compra.id_compra);
    
    let tablaHtml = '';
    let subtotalCalculado = 0;

    lineas.forEach((l, index) => {
      const material = this.materiales.find(m => m.id_material == l.id_material);
      const matNombre = material ? material.nombre : `Material #${l.id_material}`;
      const precio = Number(l.precio || 0);
      const cant = Number(l.cantidad || 0);
      const sub = precio * cant;
      subtotalCalculado += sub;

      tablaHtml += `
        <tr>
          <td style="text-align: center;">${index + 1}</td>
          <td><strong>${matNombre}</strong></td>
          <td style="text-align: right;">${cant}</td>
          <td style="text-align: right;">${precio.toFixed(2)} Bs</td>
          <td style="text-align: right; font-weight: bold;">${sub.toFixed(2)} Bs</td>
        </tr>
      `;
    });

    if (lineas.length === 0) {
      tablaHtml = `<tr><td colspan="5" style="text-align: center; font-style: italic; color: #666;">No hay detalles registrados para esta compra</td></tr>`;
    }

    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('Por favor permite las ventanas emergentes en tu navegador.');
      return;
    }

    const totalCompra = Number(compra.total || subtotalCalculado || 0).toFixed(2);

    printWindow.document.write(`
      <html>
        <head>
          <title>Orden de Compra #${compra.id_compra}</title>
          <style>
            body {
              font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
              color: #333;
              margin: 40px;
              line-height: 1.6;
            }
            .header-container {
              display: flex;
              justify-content: space-between;
              border-bottom: 3px double #0d2c6c;
              padding-bottom: 20px;
              margin-bottom: 30px;
            }
            .company-details h1 {
              color: #0d2c6c;
              margin: 0 0 5px 0;
              font-size: 28px;
              font-weight: 800;
            }
            .company-details p {
              margin: 0;
              font-size: 13px;
              color: #555;
            }
            .order-title {
              text-align: right;
            }
            .order-title h2 {
              color: #ff7043;
              margin: 0 0 5px 0;
              font-size: 24px;
            }
            .order-title p {
              margin: 0;
              font-size: 13px;
              font-weight: bold;
            }
            .info-section {
              display: flex;
              justify-content: space-between;
              margin-bottom: 30px;
              background: #f8fafc;
              padding: 15px 20px;
              border-radius: 8px;
              border: 1px solid #e2e8f0;
            }
            .info-block h3 {
              margin: 0 0 8px 0;
              font-size: 14px;
              color: #0d2c6c;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
            .info-block p {
              margin: 3px 0;
              font-size: 13px;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              margin-bottom: 40px;
            }
            th {
              background-color: #0d2c6c;
              color: white;
              padding: 12px;
              font-size: 13px;
              text-align: left;
              text-transform: uppercase;
            }
            td {
              padding: 12px;
              border-bottom: 1px solid #e2e8f0;
              font-size: 13px;
            }
            .totals-row td {
              border-bottom: none;
              font-size: 15px;
            }
            .totals-row.grand-total td {
              font-size: 18px;
              color: #ff7043;
            }
            .signature-section {
              margin-top: 80px;
              display: flex;
              justify-content: space-between;
            }
            .signature-block {
              text-align: center;
              width: 200px;
            }
            .signature-line {
              border-top: 1px solid #999;
              margin-bottom: 8px;
            }
            .signature-block p {
              margin: 0;
              font-size: 12px;
              color: #666;
            }
          </style>
        </head>
        <body>
          <div class="header-container">
            <div class="company-details">
              <h1>🏢 CONSTRUCTPRO</h1>
              <p>Constructora y Logística de Obra S.A.</p>
              <p>Av. Banzer 4to Anillo, Edificio Empresarial, Of. 302</p>
              <p>Telf: +591 3-3456789 | Santa Cruz, Bolivia</p>
            </div>
            <div class="order-title">
              <h2>ORDEN DE COMPRA</h2>
              <p>Nº: 000${compra.id_compra}</p>
              <p>Fecha: ${compra.fecha || new Date().toLocaleDateString()}</p>
              <p>Estado: ${compra.estado.toUpperCase()}</p>
            </div>
          </div>

          <div class="info-section">
            <div class="info-block">
              <h3>Proveedor</h3>
              <p><strong>${proveedorNombre}</strong></p>
              <p>Contacto/Telf: ${compra.id_proveedor ? (this.proveedores.find(p => p.id_proveedor == compra.id_proveedor)?.contacto || 'No disponible') : ''}</p>
              <p>Santa Cruz, Bolivia</p>
            </div>
            <div class="info-block" style="text-align: right;">
              <h3>Facturar A</h3>
              <p><strong>ConstructPro Central</strong></p>
              <p>NIT: 382910023</p>
              <p>Encargado: Administración General</p>
            </div>
          </div>

          <table>
            <thead>
              <tr>
                <th style="width: 5%; text-align: center;">Item</th>
                <th style="width: 50%;">Descripción del Material</th>
                <th style="width: 15%; text-align: right;">Cantidad</th>
                <th style="width: 15%; text-align: right;">Precio Unit.</th>
                <th style="width: 15%; text-align: right;">Total</th>
              </tr>
            </thead>
            <tbody>
              ${tablaHtml}
              <tr class="totals-row">
                <td colspan="3"></td>
                <td style="text-align: right; font-weight: bold; color: #555;">Subtotal:</td>
                <td style="text-align: right; font-weight: bold; color: #555;">${Number(subtotalCalculado).toFixed(2)} Bs</td>
              </tr>
              <tr class="totals-row grand-total">
                <td colspan="3"></td>
                <td style="text-align: right; font-weight: 800;">TOTAL NETO:</td>
                <td style="text-align: right; font-weight: 800;">${totalCompra} Bs</td>
              </tr>
            </tbody>
          </table>

          <div class="signature-section">
            <div class="signature-block">
              <div class="signature-line"></div>
              <p><strong>Preparado Por</strong></p>
              <p>Departamento de Compras</p>
            </div>
            <div class="signature-block">
              <div class="signature-line"></div>
              <p><strong>Aprobado Por</strong></p>
              <p>Administración General</p>
            </div>
          </div>

          <script>
            window.onload = function() {
              window.print();
            };
          </script>
        </body>
      </html>
    `);
    printWindow.document.close();
  }

}