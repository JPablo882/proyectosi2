from datetime import date
from decimal import Decimal
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from sqlmodel import Session, select, col

from database_empresa import get_session_empresa
from utils.seguridad_roles import requerir_roles
from utils.bitacora import registrar_bitacora
from models import Cotizacion, Usuario


router = APIRouter(
    prefix="/cotizaciones",
    tags=["Cotizaciones - Gestión"]
)


# ============================================================
# MODELOS DE REQUEST / RESPONSE
# ============================================================

class CrearCotizacionRequest(BaseModel):
    nombre: Optional[str] = "Proyecto Sin Nombre"
    ubicacion: str = Field(..., min_length=2)
    m2_terreno: int = Field(default=0, ge=0)
    m2_construir: int = Field(default=100, ge=0)
    habitaciones: int = Field(default=1, ge=0)
    banos: int = Field(default=1, ge=0)
    calidad_materiales: str = Field(default="Estándar")
    ambientes: List[str] = Field(default_factory=list)
    adicionales: Optional[str] = None
    costo_estimado: Decimal = Field(..., ge=Decimal("0"))


class ActualizarEstadoRequest(BaseModel):
    estado: str = Field(..., pattern="^(Pendiente|Aprobado|Rechazado)$")


class CotizacionResponse(BaseModel):
    id_cotizacion: int
    id_usuarios: Optional[int]
    nombre: Optional[str]
    ubicacion: str
    m2_terreno: int
    m2_construir: int
    habitaciones: int
    banos: int
    calidad_materiales: str
    ambientes: List[str]
    adicionales: Optional[str]
    costo_estimado: Decimal
    fecha: date
    estado: str


# ============================================================
# ENDPOINTS
# ============================================================

@router.post("", response_model=CotizacionResponse)
def crear_cotizacion(
    datos: CrearCotizacionRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    """
    Crea una nueva cotización asociada al usuario/cliente autenticado.
    """
    usuario: Usuario = usuario_actual["usuario"]
    id_usuario = usuario.id_usuarios
    ambientes_str = ",".join(datos.ambientes)

    nueva_cotizacion = Cotizacion(
        id_usuarios=id_usuario,
        nombre=datos.nombre or "Proyecto Sin Nombre",
        ubicacion=datos.ubicacion,
        m2_terreno=datos.m2_terreno,
        m2_construir=datos.m2_construir,
        habitaciones=datos.habitaciones,
        banos=datos.banos,
        calidad_materiales=datos.calidad_materiales,
        ambientes=ambientes_str,
        adicionales=datos.adicionales,
        costo_estimado=datos.costo_estimado,
        fecha=date.today(),
        estado="Pendiente"
    )

    session.add(nueva_cotizacion)
    session.commit()
    session.refresh(nueva_cotizacion)

    # Registrar en bitácora
    registrar_bitacora(
        session=session,
        id_usuario=id_usuario or 0,
        modulo="Cotizaciones",
        accion="Creación de cotización",
        descripcion=f"Cotización ID {nueva_cotizacion.id_cotizacion} creada por valor de {nueva_cotizacion.costo_estimado} Bs.",
    )

    # Notificar al cliente sobre la cotización validada/aprobada por la IA
    try:
        from routers.notificaciones_app import enviar_notificacion_push
        if id_usuario:
            enviar_notificacion_push(
                id_usuario=id_usuario,
                titulo="Cotización validada por la IA",
                mensaje=f"La IA del asistente ha validado y aprobado tu cotización para '{nueva_cotizacion.nombre}' por un costo estimado de {nueva_cotizacion.costo_estimado} Bs.",
                data={"id_cotizacion": str(nueva_cotizacion.id_cotizacion), "tipo": "cotizacion"}
            )
    except Exception as e:
        print(f"Error al enviar notificación de cotización: {e}")

    # Retornar respuesta mapeada
    return CotizacionResponse(
        id_cotizacion=nueva_cotizacion.id_cotizacion or 0,
        id_usuarios=nueva_cotizacion.id_usuarios,
        nombre=nueva_cotizacion.nombre or "Proyecto Sin Nombre",
        ubicacion=nueva_cotizacion.ubicacion,
        m2_terreno=nueva_cotizacion.m2_terreno,
        m2_construir=nueva_cotizacion.m2_construir,
        habitaciones=nueva_cotizacion.habitaciones,
        banos=nueva_cotizacion.banos,
        calidad_materiales=nueva_cotizacion.calidad_materiales,
        ambientes=nueva_cotizacion.ambientes.split(",") if nueva_cotizacion.ambientes else [],
        adicionales=nueva_cotizacion.adicionales,
        costo_estimado=nueva_cotizacion.costo_estimado,
        fecha=nueva_cotizacion.fecha or date.today(),
        estado=nueva_cotizacion.estado
    )


@router.get("/mis-cotizaciones", response_model=List[CotizacionResponse])
def listar_mis_cotizaciones(
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    """
    Lista todas las cotizaciones creadas por el cliente autenticado.
    """
    usuario: Usuario = usuario_actual["usuario"]
    id_usuario = usuario.id_usuarios
    
    cotizaciones = session.exec(
        select(Cotizacion)
        .where(Cotizacion.id_usuarios == id_usuario)
        .order_by(col(Cotizacion.fecha).desc())
    ).all()

    return [
        CotizacionResponse(
            id_cotizacion=c.id_cotizacion or 0,
            id_usuarios=c.id_usuarios,
            nombre=c.nombre or "Proyecto Sin Nombre",
            ubicacion=c.ubicacion,
            m2_terreno=c.m2_terreno,
            m2_construir=c.m2_construir,
            habitaciones=c.habitaciones,
            banos=c.banos,
            calidad_materiales=c.calidad_materiales,
            ambientes=c.ambientes.split(",") if c.ambientes else [],
            adicionales=c.adicionales,
            costo_estimado=c.costo_estimado,
            fecha=c.fecha or date.today(),
            estado=c.estado
        )
        for c in cotizaciones
    ]


@router.get("", response_model=List[CotizacionResponse])
def listar_todas_las_cotizaciones(
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado")),
):
    """
    Lista todas las cotizaciones del sistema (solo para Administrador o Empleado).
    """
    cotizaciones = session.exec(
        select(Cotizacion).order_by(col(Cotizacion.fecha).desc())
    ).all()

    return [
        CotizacionResponse(
            id_cotizacion=c.id_cotizacion or 0,
            id_usuarios=c.id_usuarios,
            nombre=c.nombre or "Proyecto Sin Nombre",
            ubicacion=c.ubicacion,
            m2_terreno=c.m2_terreno,
            m2_construir=c.m2_construir,
            habitaciones=c.habitaciones,
            banos=c.banos,
            calidad_materiales=c.calidad_materiales,
            ambientes=c.ambientes.split(",") if c.ambientes else [],
            adicionales=c.adicionales,
            costo_estimado=c.costo_estimado,
            fecha=c.fecha or date.today(),
            estado=c.estado
        )
        for c in cotizaciones
    ]


@router.put("/{id_cotizacion}/estado")
def actualizar_estado_cotizacion(
    id_cotizacion: int,
    datos: ActualizarEstadoRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado")),
):
    """
    Actualiza el estado de una cotización (por ejemplo a Aprobado o Rechazado).
    """
    cotizacion = session.get(Cotizacion, id_cotizacion)

    if not cotizacion:
        raise HTTPException(
            status_code=404,
            detail=f"Cotización con ID {id_cotizacion} no encontrada."
        )

    estado_anterior = cotizacion.estado
    cotizacion.estado = datos.estado
    session.add(cotizacion)
    session.commit()

    usuario: Usuario = usuario_actual["usuario"]

    # Registrar en bitácora
    registrar_bitacora(
        session=session,
        id_usuario=usuario.id_usuarios or 0,
        modulo="Cotizaciones",
        accion="Actualización de estado",
        descripcion=f"Estado de cotización ID {id_cotizacion} cambiado de {estado_anterior} a {datos.estado}.",
    )

    return {
        "mensaje": "Estado de cotización actualizado correctamente.",
        "id_cotizacion": id_cotizacion,
        "nuevo_estado": datos.estado
    }
