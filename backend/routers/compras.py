from datetime import date
from decimal import Decimal
from fastapi import Depends, HTTPException
from sqlmodel import Session
from database_empresa import get_session_empresa
from models import MovimientoFinanciero
from crud.factory import crear_crud_router
from pydantic import BaseModel

from models import Material, Proveedor, Compra, DetalleCompra, Proyecto


material_router = crear_crud_router(
    modelo=Material,
    prefix="/materiales",
    tags=["Compras - Materiales"],
    campos_pk=("id_material",),
)

proveedor_router = crear_crud_router(
    modelo=Proveedor,
    prefix="/proveedores",
    tags=["Compras - Proveedores"],
    campos_pk=("id_proveedor",),
)

compra_router = crear_crud_router(
    modelo=Compra,
    prefix="/compras",
    tags=["Compras - Compras"],
    campos_pk=("id_compra",),
)

@compra_router.post("/{id_compra}/aprobar")
def aprobar_compra(
    id_compra: int,
    session: Session = Depends(get_session_empresa)
):
    compra = session.get(Compra, id_compra)
    if not compra:
        raise HTTPException(status_code=404, detail="Compra no encontrada")
    
    if compra.estado == "Aprobada":
        raise HTTPException(status_code=400, detail="La compra ya ha sido aprobada anteriormente")
        
    # Crear el movimiento financiero asociado de tipo Egreso
    movimiento = MovimientoFinanciero(
        id_proyecto=None,
        tipo_movimiento="Egreso",
        categoria="Compras",
        monto=compra.total,
        fecha=compra.fecha or date.today(),
        descripcion=f"Aprobación de Orden de Compra #{compra.id_compra}"
    )
    session.add(movimiento)
    session.commit()
    session.refresh(movimiento)
    
    compra.id_movimiento = movimiento.id_movimiento
    compra.estado = "Aprobada"
    session.add(compra)
    session.commit()
    session.refresh(compra)
    
    # Notificación SSE
    try:
        from routers.notificaciones_app import enviar_notificacion_push
        if compra.id_usuarios:
            enviar_notificacion_push(
                id_usuario=compra.id_usuarios,
                titulo=f"Orden de Compra #{compra.id_compra} Aprobada",
                mensaje=f"Tu orden de compra por un total de {compra.total} Bs. ha sido aprobada.",
                data={"id_compra": str(compra.id_compra), "tipo": "compra"}
            )
    except Exception as e:
        print(f"Error al enviar notificación de aprobación de compra: {e}")
        
    return {"mensaje": "Compra aprobada correctamente", "compra": compra}


@compra_router.post("/{id_compra}/rechazar")
def rechazar_compra(
    id_compra: int,
    session: Session = Depends(get_session_empresa)
):
    compra = session.get(Compra, id_compra)
    if not compra:
        raise HTTPException(status_code=404, detail="Compra no encontrada")
    
    if compra.estado != "Pendiente":
        raise HTTPException(status_code=400, detail=f"La compra no está pendiente, su estado es: {compra.estado}")
        
    compra.estado = "Rechazada"
    session.add(compra)
    session.commit()
    session.refresh(compra)
    
    # Notificación SSE
    try:
        from routers.notificaciones_app import enviar_notificacion_push
        if compra.id_usuarios:
            enviar_notificacion_push(
                id_usuario=compra.id_usuarios,
                titulo=f"Orden de Compra #{compra.id_compra} Rechazada",
                mensaje=f"Tu orden de compra por un total de {compra.total} Bs. ha sido rechazada.",
                data={"id_compra": str(compra.id_compra), "tipo": "compra"}
            )
    except Exception as e:
        print(f"Error al enviar notificación de rechazo de compra: {e}")
        
    return {"mensaje": "Compra rechazada correctamente", "compra": compra}


class OcuparMaterialRequest(BaseModel):
    id_material: int
    id_proyecto: int
    cantidad: int


@material_router.post("/ocupar")
def ocupar_material(
    datos: OcuparMaterialRequest,
    session: Session = Depends(get_session_empresa)
):
    material = session.get(Material, datos.id_material)
    if not material:
        raise HTTPException(status_code=404, detail="Material no encontrado")
        
    proyecto = session.get(Proyecto, datos.id_proyecto)
    if not proyecto:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
        
    if datos.cantidad <= 0:
        raise HTTPException(status_code=400, detail="La cantidad debe ser mayor a 0")
        
    if material.stock < datos.cantidad:
        raise HTTPException(status_code=400, detail=f"Stock insuficiente. Stock actual: {material.stock}")
        
    # Descontar del inventario
    material.stock -= datos.cantidad
    session.add(material)
    
    # Registrar el movimiento financiero como egreso en el proyecto
    costo_total = Decimal(str(material.precio)) * Decimal(str(datos.cantidad))
    movimiento = MovimientoFinanciero(
        id_proyecto=datos.id_proyecto,
        tipo_movimiento="Egreso",
        categoria="Materiales",
        monto=costo_total,
        fecha=date.today(),
        descripcion=f"Consumo de material: {datos.cantidad} x {material.nombre} para el proyecto: {proyecto.nombre}"
    )
    session.add(movimiento)
    session.commit()
    session.refresh(material)
    
    return {
        "mensaje": f"Se han descontado {datos.cantidad} unidades de {material.nombre} para el proyecto '{proyecto.nombre}'.",
        "stock_restante": material.stock,
        "costo_total": costo_total
    }


detalle_compra_router = crear_crud_router(
    modelo=DetalleCompra,
    prefix="/detalle-compras",
    tags=["Compras - Detalle compras"],
    campos_pk=("id",),
)


routers = [
    material_router,
    proveedor_router,
    compra_router,
    detalle_compra_router,
]