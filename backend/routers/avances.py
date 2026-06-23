from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from models import AvanceProyecto
from database_empresa import get_session_empresa

router = APIRouter(
    prefix="/avances",
    tags=["Avances de Proyecto"]
)


@router.post("/")
def registrar_avance(
    avance: AvanceProyecto,
    session: Session = Depends(get_session_empresa)
):

    session.add(avance)

    session.commit()

    session.refresh(avance)

    # Notificar al cliente sobre el nuevo avance registrado en tiempo real
    try:
        from models import Proyecto
        from routers.notificaciones_app import enviar_notificacion_push
        proyecto = session.get(Proyecto, avance.id_proyecto)
        if proyecto and proyecto.id_usuarios:
            enviar_notificacion_push(
                id_usuario=proyecto.id_usuarios,
                titulo=f"Nuevo avance registrado: {proyecto.nombre}",
                mensaje=f"Se ha registrado el avance '{avance.titulo}' con un {avance.porcentaje_avance}% de progreso.",
                data={"id_proyecto": str(proyecto.id_proyecto), "tipo": "avance"}
            )
    except Exception as e:
        print(f"Error al enviar notificación de avance: {e}")

    return avance


@router.get("/")
def listar_avances(
    session: Session = Depends(get_session_empresa)
):

    return session.exec(
        select(AvanceProyecto)
    ).all()


@router.get("/proyecto/{id_proyecto}")
def avances_proyecto(
    id_proyecto: int,
    session: Session = Depends(get_session_empresa)
):

    return session.exec(
        select(AvanceProyecto)
        .where(
            AvanceProyecto.id_proyecto == id_proyecto
        )
    ).all()