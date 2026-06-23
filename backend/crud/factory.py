from typing import Any, Dict, List, Type

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import SQLModel, Session, select
from sqlalchemy.exc import SQLAlchemyError

from database import get_session
from database_empresa import get_session_empresa
from utils.bitacora import registrar_bitacora
from utils.seguridad_roles import requerir_roles, permitir_sin_usuario


def convertir_a_dict(objeto):
    if hasattr(objeto, "model_dump"):
        return objeto.model_dump()
    return objeto.dict()


def crear_objeto(modelo: Type[SQLModel], data: Dict[str, Any]):
    try:
        return modelo(**data)
    except Exception as error:
        raise HTTPException(
            status_code=400,
            detail=f"Datos inválidos para {modelo.__name__}: {str(error)}",
        )


def manejar_error_bd(session: Session, error: SQLAlchemyError):
    session.rollback()
    detalle = str(getattr(error, "orig", error))
    raise HTTPException(status_code=400, detail=detalle)


def registrar_accion_crud(
    session: Session,
    usuario_actual,
    modulo: str,
    accion: str,
    descripcion: str,
):
    if usuario_actual and isinstance(usuario_actual, dict):
        usuario = usuario_actual.get("usuario")

        if usuario and getattr(usuario, "id_usuarios", None):
            registrar_bitacora(
                session=session,
                id_usuario=usuario.id_usuarios,
                modulo=modulo,
                accion=accion,
                descripcion=descripcion,
            )


from typing import Any, Dict, List, Type, Tuple

def crear_crud_router(
    modelo: Type[SQLModel],
    prefix: str,
    tags: List[str],
    campos_pk: Tuple[str, ...],
    usar_bd_empresa: bool = True,
    proteger: bool = True,
    roles_listar: Tuple[str, ...] = ("Administrador", "Empleado", "Cliente"),
    roles_crear: Tuple[str, ...] = ("Administrador", "Empleado"),
    roles_actualizar: Tuple[str, ...] = ("Administrador", "Empleado"),
    roles_eliminar: Tuple[str, ...] = ("Administrador",),
):
    router = APIRouter(prefix=prefix, tags=tags)  # type: ignore

    nombre_ruta = prefix.strip("/").replace("-", "_").replace("/", "_")

    session_dependency = get_session_empresa if usar_bd_empresa else get_session

    dependencia_listar = requerir_roles(*roles_listar) if proteger else permitir_sin_usuario
    dependencia_crear = requerir_roles(*roles_crear) if proteger else permitir_sin_usuario
    dependencia_actualizar = requerir_roles(*roles_actualizar) if proteger else permitir_sin_usuario
    dependencia_eliminar = requerir_roles(*roles_eliminar) if proteger else permitir_sin_usuario

    # ============================================================
    # LISTAR
    # ============================================================

    def listar(
        session: Session = Depends(session_dependency),
        usuario_actual=Depends(dependencia_listar),
    ):
        return session.exec(select(modelo)).all()

    listar.__name__ = f"listar_{nombre_ruta}"

    router.add_api_route(
        "",
        listar,
        methods=["GET"],
        summary=f"Listar {prefix}",
        response_model=List[modelo],
    )

    # ============================================================
    # CREAR
    # ============================================================

    def crear(
        data: Dict[str, Any],
        session: Session = Depends(session_dependency),
        usuario_actual=Depends(dependencia_crear),
    ):
        objeto = crear_objeto(modelo, data)

        try:
            session.add(objeto)
            session.commit()
            session.refresh(objeto)

            registrar_accion_crud(
                session=session,
                usuario_actual=usuario_actual,
                modulo=prefix,
                accion="Crear",
                descripcion=f"Se creó un registro en {modelo.__name__}.",
            )

            return objeto

        except SQLAlchemyError as error:
            manejar_error_bd(session, error)

    crear.__name__ = f"crear_{nombre_ruta}"

    router.add_api_route(
        "",
        crear,
        methods=["POST"],
        summary=f"Crear {prefix}",
        response_model=modelo,
    )

    # ============================================================
    # CLAVE PRIMARIA SIMPLE
    # ============================================================

    if len(campos_pk) == 1:
        campo_pk = campos_pk[0]

        def obtener(
            item_id: int,
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_listar),
        ):
            objeto = session.get(modelo, item_id)

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            return objeto

        obtener.__name__ = f"obtener_{nombre_ruta}"

        router.add_api_route(
            "/{item_id}",
            obtener,
            methods=["GET"],
            summary=f"Obtener {prefix} por ID",
            response_model=modelo,
        )

        def actualizar(
            item_id: int,
            data: Dict[str, Any],
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_actualizar),
        ):
            objeto = session.get(modelo, item_id)

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            estado_anterior = None
            if modelo.__name__ == "Proyecto":
                estado_anterior = getattr(objeto, "estado", None)

            datos_actuales = convertir_a_dict(objeto)
            datos_nuevos = {**datos_actuales, **data}
            datos_nuevos[campo_pk] = item_id

            if modelo.__name__ == "Proyecto":
                estado_nuevo = datos_nuevos.get("estado")
                if estado_nuevo == "Finalizado" and estado_anterior != "Finalizado":
                    from datetime import date
                    datos_nuevos["fecha_fin"] = date.today().isoformat()

            objeto_validado = crear_objeto(modelo, datos_nuevos)

            for campo, valor in convertir_a_dict(objeto_validado).items():
                if campo != campo_pk:
                    setattr(objeto, campo, valor)

            try:
                session.add(objeto)
                session.commit()
                session.refresh(objeto)

                registrar_accion_crud(
                    session=session,
                    usuario_actual=usuario_actual,
                    modulo=prefix,
                    accion="Actualizar",
                    descripcion=f"Se actualizó {modelo.__name__} con ID {item_id}.",
                )

                if modelo.__name__ == "Proyecto":
                    estado_nuevo = getattr(objeto, "estado", None)
                    if estado_anterior != estado_nuevo:
                        from routers.notificaciones_app import enviar_notificacion_push
                        from datetime import datetime
                        fecha_hora = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
                        nombre_proy = getattr(objeto, "nombre", f"Proyecto #{item_id}")
                        mensaje = f"Proyecto: {nombre_proy}\nCambió a: {estado_nuevo}\nFecha: {fecha_hora}"
                        
                        id_usr = getattr(objeto, "id_usuarios", None)
                        if id_usr:
                            enviar_notificacion_push(
                                id_usuario=id_usr,
                                titulo="¡Cambio de Estado de Proyecto!",
                                mensaje=mensaje
                            )

                return objeto

            except SQLAlchemyError as error:
                manejar_error_bd(session, error)

        actualizar.__name__ = f"actualizar_{nombre_ruta}"

        router.add_api_route(
            "/{item_id}",
            actualizar,
            methods=["PUT"],
            summary=f"Actualizar {prefix} por ID",
            response_model=modelo,
        )

        def eliminar(
            item_id: int,
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_eliminar),
        ):
            objeto = session.get(modelo, item_id)

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            try:
                # Manual cascade to prevent foreign key constraint violations
                if modelo.__name__ == "Empleados":
                    from models import Planillas, Proyecto
                    # Delete associated planillas
                    planillas_asociadas = session.exec(
                        select(Planillas).where(Planillas.id_empleados == item_id)
                    ).all()
                    for planilla in planillas_asociadas:
                        session.delete(planilla)
                    
                    # Nullify references in Proyecto
                    proyectos_asociados = session.exec(
                        select(Proyecto).where(
                            (Proyecto.id_ingeniero == item_id) |
                            (Proyecto.id_residente == item_id) |
                            (Proyecto.id_maestro == item_id)
                        )
                    ).all()
                    for proyecto in proyectos_asociados:
                        if proyecto.id_ingeniero == item_id:
                            proyecto.id_ingeniero = None
                        if proyecto.id_residente == item_id:
                            proyecto.id_residente = None
                        if proyecto.id_maestro == item_id:
                            proyecto.id_maestro = None
                        session.add(proyecto)

                    # Remove from arrays (id_albaniles, id_ayudantes)
                    all_proyectos = session.exec(select(Proyecto)).all()
                    for proyecto in all_proyectos:
                        modificado = False
                        if proyecto.id_albaniles and item_id in proyecto.id_albaniles:
                            proyecto.id_albaniles = [x for x in proyecto.id_albaniles if x != item_id]
                            modificado = True
                        if proyecto.id_ayudantes and item_id in proyecto.id_ayudantes:
                            proyecto.id_ayudantes = [x for x in proyecto.id_ayudantes if x != item_id]
                            modificado = True
                        if modificado:
                            session.add(proyecto)
                    
                    session.commit()

                elif modelo.__name__ == "Cliente":
                    from models import Venta, Pago, MovimientoFinanciero
                    ventas_asociadas = session.exec(
                        select(Venta).where(Venta.id_cliente == item_id)
                    ).all()
                    for venta in ventas_asociadas:
                        # Delete associated pagos
                        pagos_asociados = session.exec(
                            select(Pago).where(Pago.id_venta == venta.id_venta)
                        ).all()
                        for pago in pagos_asociados:
                            session.delete(pago)
                        
                        # Delete associated financial movement
                        if venta.id_movimiento:
                            mov = session.get(MovimientoFinanciero, venta.id_movimiento)
                            if mov:
                                session.delete(mov)
                        
                        session.delete(venta)
                    
                    session.commit()

                session.delete(objeto)
                session.commit()

                registrar_accion_crud(
                    session=session,
                    usuario_actual=usuario_actual,
                    modulo=prefix,
                    accion="Eliminar",
                    descripcion=f"Se eliminó {modelo.__name__} con ID {item_id}.",
                )

                return {
                    "mensaje": f"{modelo.__name__} eliminado correctamente"
                }

            except SQLAlchemyError as error:
                manejar_error_bd(session, error)

        eliminar.__name__ = f"eliminar_{nombre_ruta}"

        router.add_api_route(
            "/{item_id}",
            eliminar,
            methods=["DELETE"],
            summary=f"Eliminar {prefix} por ID",
        )

    # ============================================================
    # CLAVE PRIMARIA COMPUESTA
    # ============================================================

    else:
        def obtener_compuesto(
            pk1: int,
            pk2: int,
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_listar),
        ):
            objeto = session.get(modelo, (pk1, pk2))

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            return objeto

        obtener_compuesto.__name__ = f"obtener_{nombre_ruta}"

        router.add_api_route(
            "/{pk1}/{pk2}",
            obtener_compuesto,
            methods=["GET"],
            summary=f"Obtener {prefix} por clave compuesta",
            response_model=modelo,
        )

        def actualizar_compuesto(
            pk1: int,
            pk2: int,
            data: Dict[str, Any],
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_actualizar),
        ):
            objeto = session.get(modelo, (pk1, pk2))

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            datos_actuales = convertir_a_dict(objeto)
            datos_nuevos = {**datos_actuales, **data}
            datos_nuevos[campos_pk[0]] = pk1
            datos_nuevos[campos_pk[1]] = pk2

            objeto_validado = crear_objeto(modelo, datos_nuevos)

            for campo, valor in convertir_a_dict(objeto_validado).items():
                if campo not in campos_pk:
                    setattr(objeto, campo, valor)

            try:
                session.add(objeto)
                session.commit()
                session.refresh(objeto)

                registrar_accion_crud(
                    session=session,
                    usuario_actual=usuario_actual,
                    modulo=prefix,
                    accion="Actualizar",
                    descripcion=f"Se actualizó {modelo.__name__} con clave ({pk1}, {pk2}).",
                )

                return objeto

            except SQLAlchemyError as error:
                manejar_error_bd(session, error)

        actualizar_compuesto.__name__ = f"actualizar_{nombre_ruta}"

        router.add_api_route(
            "/{pk1}/{pk2}",
            actualizar_compuesto,
            methods=["PUT"],
            summary=f"Actualizar {prefix} por clave compuesta",
            response_model=modelo,
        )

        def eliminar_compuesto(
            pk1: int,
            pk2: int,
            session: Session = Depends(session_dependency),
            usuario_actual=Depends(dependencia_eliminar),
        ):
            objeto = session.get(modelo, (pk1, pk2))

            if not objeto:
                raise HTTPException(
                    status_code=404,
                    detail=f"{modelo.__name__} no encontrado",
                )

            try:
                session.delete(objeto)
                session.commit()

                registrar_accion_crud(
                    session=session,
                    usuario_actual=usuario_actual,
                    modulo=prefix,
                    accion="Eliminar",
                    descripcion=f"Se eliminó {modelo.__name__} con clave ({pk1}, {pk2}).",
                )

                return {
                    "mensaje": f"{modelo.__name__} eliminado correctamente"
                }

            except SQLAlchemyError as error:
                manejar_error_bd(session, error)

        eliminar_compuesto.__name__ = f"eliminar_{nombre_ruta}"

        router.add_api_route(
            "/{pk1}/{pk2}",
            eliminar_compuesto,
            methods=["DELETE"],
            summary=f"Eliminar {prefix} por clave compuesta",
        )

    return router