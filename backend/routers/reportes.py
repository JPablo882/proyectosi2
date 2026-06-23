from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func
from sqlmodel import Session, select

from database_empresa import get_session_empresa
from models import (
    Proyecto,
    Material,
    Presupuesto,
    MovimientoFinanciero,
    Planillas,
    ActivosFijos,
    Usuario,
    Empleados,
    Compra,
)


router = APIRouter(
    prefix="/reportes",
    tags=["Reportes Multiempresa"]
)


def redondear(valor) -> Decimal:
    return Decimal(str(valor or 0)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP
    )


class ReporteGeneralResponse(BaseModel):
    total_proyectos: int
    total_materiales: int
    total_usuarios: int
    total_empleados: int
    total_presupuestado_bob: Decimal
    total_ingresos_bob: Decimal
    total_egresos_bob: Decimal
    valor_total_activos_bob: Decimal
    valor_inventario_materiales_bob: Decimal


@router.get("/general", response_model=ReporteGeneralResponse)
def reporte_general(
    session: Session = Depends(get_session_empresa),
):
    total_proyectos = session.exec(
        select(func.count(Proyecto.id_proyecto))
    ).one()

    total_materiales = session.exec(
        select(func.count(Material.id_material))
    ).one()

    total_usuarios = session.exec(
        select(func.count(Usuario.id_usuarios))
    ).one()

    total_empleados = session.exec(
        select(func.count(Empleados.id_empleados))
    ).one()

    total_presupuestado = session.exec(
        select(func.coalesce(func.sum(Presupuesto.costo_total), 0))
    ).one()

    total_ingresos = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(func.lower(MovimientoFinanciero.tipo_movimiento) == "ingreso")
    ).one()

    total_egresos = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(func.lower(MovimientoFinanciero.tipo_movimiento) == "egreso")
    ).one()

    valor_total_activos = session.exec(
        select(func.coalesce(func.sum(ActivosFijos.valor_compra), 0))
    ).one()

    materiales = session.exec(select(Material)).all()

    valor_inventario = Decimal("0")

    for material in materiales:
        precio = Decimal(str(material.precio or 0))
        stock = Decimal(str(material.stock or 0))
        valor_inventario += precio * stock

    return {
        "total_proyectos": int(total_proyectos or 0),
        "total_materiales": int(total_materiales or 0),
        "total_usuarios": int(total_usuarios or 0),
        "total_empleados": int(total_empleados or 0),
        "total_presupuestado_bob": redondear(total_presupuestado),
        "total_ingresos_bob": redondear(total_ingresos),
        "total_egresos_bob": redondear(total_egresos),
        "valor_total_activos_bob": redondear(valor_total_activos),
        "valor_inventario_materiales_bob": redondear(valor_inventario),
    }


class ReporteProyectoResponse(BaseModel):
    id_proyecto: int
    nombre_proyecto: str
    ubicacion: str
    estado: str
    total_presupuestado_bob: Decimal
    total_ingresos_bob: Decimal
    total_egresos_bob: Decimal
    total_planillas_bob: Decimal
    valor_activos_bob: Decimal
    gasto_total_bob: Decimal
    saldo_estimado_bob: Decimal
    diferencia_presupuesto_vs_gasto_bob: Decimal


@router.get("/proyecto/{id_proyecto}", response_model=ReporteProyectoResponse)
def reporte_por_proyecto(
    id_proyecto: int,
    session: Session = Depends(get_session_empresa),
):
    proyecto = session.get(Proyecto, id_proyecto)

    if not proyecto:
        raise HTTPException(
            status_code=404,
            detail="Proyecto no encontrado para esta empresa."
        )

    total_presupuestado = session.exec(
        select(func.coalesce(func.sum(Presupuesto.costo_total), 0))
        .where(Presupuesto.id_proyecto == id_proyecto)
    ).one()

    total_ingresos = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(
            MovimientoFinanciero.id_proyecto == id_proyecto,
            func.lower(MovimientoFinanciero.tipo_movimiento) == "ingreso"
        )
    ).one()

    total_egresos = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(
            MovimientoFinanciero.id_proyecto == id_proyecto,
            func.lower(MovimientoFinanciero.tipo_movimiento) == "egreso"
        )
    ).one()

    total_planillas = session.exec(
        select(func.coalesce(func.sum(Planillas.pago), 0))
        .where(Planillas.id_proyecto == id_proyecto)
    ).one()

    valor_activos = session.exec(
        select(func.coalesce(func.sum(ActivosFijos.valor_compra), 0))
        .where(ActivosFijos.id_proyecto == id_proyecto)
    ).one()

    gasto_total = redondear(total_egresos) + redondear(total_planillas)
    saldo_estimado = redondear(total_ingresos) - gasto_total
    diferencia_presupuesto = redondear(total_presupuestado) - gasto_total

    return {
        "id_proyecto": proyecto.id_proyecto,
        "nombre_proyecto": proyecto.nombre,
        "ubicacion": proyecto.ubicacion,
        "estado": proyecto.estado,
        "total_presupuestado_bob": redondear(total_presupuestado),
        "total_ingresos_bob": redondear(total_ingresos),
        "total_egresos_bob": redondear(total_egresos),
        "total_planillas_bob": redondear(total_planillas),
        "valor_activos_bob": redondear(valor_activos),
        "gasto_total_bob": redondear(gasto_total),
        "saldo_estimado_bob": redondear(saldo_estimado),
        "diferencia_presupuesto_vs_gasto_bob": redondear(diferencia_presupuesto),
    }


class MaterialStockItem(BaseModel):
    id_material: int
    nombre: str
    precio: Decimal
    stock: int
    valor_total_bob: Decimal
    estado_stock: str


@router.get("/materiales-stock", response_model=List[MaterialStockItem])
def reporte_materiales_stock(
    session: Session = Depends(get_session_empresa),
):
    materiales = session.exec(
        select(Material).order_by(Material.stock)
    ).all()

    respuesta = []

    for material in materiales:
        precio = Decimal(str(material.precio or 0))
        stock = int(material.stock or 0)
        valor_total = precio * Decimal(stock)

        if stock <= 0:
            estado_stock = "Sin stock"
        elif stock <= 10:
            estado_stock = "Stock bajo"
        elif stock <= 50:
            estado_stock = "Stock medio"
        else:
            estado_stock = "Stock suficiente"

        respuesta.append({
            "id_material": material.id_material,
            "nombre": material.nombre,
            "precio": redondear(precio),
            "stock": stock,
            "valor_total_bob": redondear(valor_total),
            "estado_stock": estado_stock,
        })

    return respuesta


class ActivoFijoReporteItem(BaseModel):
    id_activo: int
    id_proyecto: Optional[int]
    nombre: str
    tipo_activo: str
    codigo_activo: str
    valor_compra: Decimal
    valor_residual: Decimal
    vida_util: int
    depreciacion_total: Decimal
    costo_por_dia: Decimal
    estado: str


@router.get("/activos-fijos", response_model=List[ActivoFijoReporteItem])
def reporte_activos_fijos(
    session: Session = Depends(get_session_empresa),
):
    activos = session.exec(select(ActivosFijos)).all()

    respuesta = []

    for activo in activos:
        valor_compra = Decimal(str(activo.valor_compra or 0))
        valor_residual = Decimal(str(activo.valor_residual or 0))
        vida_util = Decimal(str(activo.vida_util or 1))

        depreciacion_total = valor_compra - valor_residual
        costo_por_dia = depreciacion_total / vida_util

        respuesta.append({
            "id_activo": activo.id_activo,
            "id_proyecto": activo.id_proyecto,
            "nombre": activo.nombre,
            "tipo_activo": activo.tipo_activo,
            "codigo_activo": activo.codigo_activo,
            "valor_compra": redondear(valor_compra),
            "valor_residual": redondear(valor_residual),
            "vida_util": activo.vida_util,
            "depreciacion_total": redondear(depreciacion_total),
            "costo_por_dia": redondear(costo_por_dia),
            "estado": activo.estado,
        })

    return respuesta


class EstadoResultadosResponse(BaseModel):
    ingresos_operativos_bob: Decimal
    inventario_inicial_bob: Decimal
    compras_totales_bob: Decimal
    inventario_final_bob: Decimal
    costo_de_ventas_bob: Decimal
    utilidad_bruta_bob: Decimal
    
    # Gastos Operativos Desglosados
    planillas_totales_bob: Decimal
    mantenimiento_totales_bob: Decimal
    depreciacion_totales_bob: Decimal
    otros_gastos_bob: Decimal
    
    gastos_operativos_bob: Decimal
    utilidad_operativa_bob: Decimal
    impuestos_bob: Decimal
    utilidad_neta_bob: Decimal


@router.get("/estado-resultados", response_model=EstadoResultadosResponse)
def reporte_estado_resultados(
    session: Session = Depends(get_session_empresa),
):
    # 1. Ingresos Operativos
    ingresos_operativos = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(func.lower(MovimientoFinanciero.tipo_movimiento) == "ingreso")
    ).one()

    # 2. Inventario Inicial (Asumido 0 históricamente)
    inventario_inicial = Decimal("0.00")

    # 3. Compras Totales
    compras_totales = session.exec(
        select(func.coalesce(func.sum(Compra.total), 0))
    ).one()

    # 4. Inventario Final (Valorizado actual)
    materiales = session.exec(select(Material)).all()
    inventario_final = Decimal("0.00")
    for material in materiales:
        precio = Decimal(str(material.precio or 0))
        stock = Decimal(str(material.stock or 0))
        inventario_final += precio * stock

    # 5. Costo de Ventas
    costo_de_ventas = inventario_inicial + redondear(compras_totales) - redondear(inventario_final)

    # 6. Utilidad Bruta
    utilidad_bruta = redondear(ingresos_operativos) - redondear(costo_de_ventas)

    # 7. Gastos de Personal / Planillas (Salarios pagados)
    planillas_totales = session.exec(
        select(func.coalesce(func.sum(Planillas.pago), 0))
    ).one()

    # 8. Gastos de Mantenimiento de Maquinaria/Activos
    from models import MantenimientoActivo
    mantenimiento_totales = session.exec(
        select(func.coalesce(func.sum(MantenimientoActivo.costo), 0))
    ).one()

    # 9. Depreciación total acumulada de activos fijos (valor_compra - valor_residual)
    activos = session.exec(select(ActivosFijos)).all()
    depreciacion_totales = Decimal("0.00")
    for activo in activos:
        val_compra = Decimal(str(activo.valor_compra or 0))
        val_residual = Decimal(str(activo.valor_residual or 0))
        depreciacion_totales += max(Decimal("0.00"), val_compra - val_residual)

    # 10. Egresos totales del sistema
    egresos_totales = session.exec(
        select(func.coalesce(func.sum(MovimientoFinanciero.monto), 0))
        .where(func.lower(MovimientoFinanciero.tipo_movimiento) == "egreso")
    ).one()

    # 11. Otros Gastos Generales y Administrativos (Egresos totales menos lo que ya contamos)
    otros_gastos = redondear(egresos_totales) - redondear(compras_totales) - redondear(planillas_totales) - redondear(mantenimiento_totales)
    if otros_gastos < 0:
        otros_gastos = Decimal("0.00")

    # 12. Suma total de Gastos Operativos
    gastos_operativos = redondear(planillas_totales) + redondear(mantenimiento_totales) + redondear(depreciacion_totales) + redondear(otros_gastos)

    # 13. Utilidad Operativa (EBIT)
    utilidad_operativa = utilidad_bruta - gastos_operativos

    # 14. Impuestos (25% de IUE)
    if utilidad_operativa > 0:
        impuestos = redondear(utilidad_operativa * Decimal("0.25"))
    else:
        impuestos = Decimal("0.00")

    # 15. Utilidad Neta
    utilidad_neta = utilidad_operativa - impuestos

    return {
        "ingresos_operativos_bob": redondear(ingresos_operativos),
        "inventario_inicial_bob": redondear(inventario_inicial),
        "compras_totales_bob": redondear(compras_totales),
        "inventario_final_bob": redondear(inventario_final),
        "costo_de_ventas_bob": redondear(costo_de_ventas),
        "utilidad_bruta_bob": redondear(utilidad_bruta),
        "planillas_totales_bob": redondear(planillas_totales),
        "mantenimiento_totales_bob": redondear(mantenimiento_totales),
        "depreciacion_totales_bob": redondear(depreciacion_totales),
        "otros_gastos_bob": redondear(otros_gastos),
        "gastos_operativos_bob": redondear(gastos_operativos),
        "utilidad_operativa_bob": redondear(utilidad_operativa),
        "impuestos_bob": redondear(impuestos),
        "utilidad_neta_bob": redondear(utilidad_neta),
    }