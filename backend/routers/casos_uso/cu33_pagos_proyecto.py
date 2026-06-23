from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlmodel import Session, select, col

from database_empresa import get_session_empresa
from utils.seguridad_roles import requerir_roles
from utils.bitacora import registrar_bitacora
from models import Pago, MovimientoFinanciero, Proyecto, Cotizacion


router = APIRouter(
    prefix="/casos-uso/hu33",
    tags=["HU-33 - Gestionar Pagos del Proyecto"]
)


def redondear(valor) -> Decimal:
    return Decimal(str(valor or 0)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP
    )


def sumar_meses(fecha: datetime, meses: int) -> datetime:
    month = fecha.month - 1 + meses
    year = fecha.year + month // 12
    month = month % 12 + 1
    day = min(fecha.day, [
        31,
        29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
        31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ][month - 1])
    return datetime(year, month, day, fecha.hour, fecha.minute, fecha.second)


def limpiar_ubicacion(ubicacion: str) -> str:
    if not ubicacion:
        return ubicacion
    parts = ubicacion.split(',')
    if len(parts) > 1 and '+' in parts[0] and len(parts[0].strip()) <= 10:
        return ','.join(parts[1:]).strip()
    return ubicacion


class CrearPagoProyectoRequest(BaseModel):
    id_venta: Optional[int] = None
    metodo_pago: str = Field(..., min_length=2)
    monto: Decimal = Field(..., gt=0)  # type: ignore
    estado: str = "Completado"
    codigo_transaccion: Optional[str] = None

    tipo_movimiento: str = "Ingreso"
    categoria: str = "Pago de proyecto"
    descripcion: Optional[str] = None


class ActualizarEstadoPagoRequest(BaseModel):
    estado: str = Field(..., min_length=2)


class SolicitarProyectoRequest(BaseModel):
    id_cotizacion: int


class EstablecerPlanRequest(BaseModel):
    tipo_plan: str
    cantidad_cuotas: Optional[int] = 10


@router.post("/proyectos/{id_proyecto}/pagos")
def crear_pago_proyecto(
    id_proyecto: int,
    datos: CrearPagoProyectoRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado")),
):
    movimiento = MovimientoFinanciero(
        id_proyecto=id_proyecto,
        tipo_movimiento=datos.tipo_movimiento,
        categoria=datos.categoria,
        monto=redondear(datos.monto),
        fecha=datetime.utcnow().date(),
        descripcion=datos.descripcion or f"Pago registrado para proyecto {id_proyecto}",
    )

    session.add(movimiento)
    session.commit()
    session.refresh(movimiento)

    pago = Pago(
        id_venta=datos.id_venta,
        id_movimiento=movimiento.id_movimiento,
        id_proyecto=id_proyecto,
        metodo_pago=datos.metodo_pago,
        monto=redondear(datos.monto),
        fecha=datetime.utcnow(),
        estado=datos.estado,
        codigo_transaccion=datos.codigo_transaccion,
    )

    session.add(pago)
    session.commit()
    session.refresh(pago)

    registrar_bitacora(
        session=session,
        id_usuario=usuario_actual["usuario"].id_usuarios,
        modulo="HU-33 - Pagos del Proyecto",
        accion="Registrar pago",
        descripcion=f"Se registró pago de {pago.monto} Bs para proyecto {id_proyecto}.",
    )

    return {
        "mensaje": "Pago del proyecto registrado correctamente.",
        "id_pago": pago.id_pago,
        "id_movimiento": movimiento.id_movimiento,
        "pago": pago,
        "movimiento_financiero": movimiento
    }


@router.get("/proyectos/{id_proyecto}/pagos", response_model=List[Pago])
def listar_pagos_proyecto(
    id_proyecto: int,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    return session.exec(
        select(Pago)
        .where(Pago.id_proyecto == id_proyecto)
        .order_by(col(Pago.fecha).desc())
    ).all()


@router.put("/pagos/{id_pago}/estado")
def actualizar_estado_pago(
    id_pago: int,
    datos: ActualizarEstadoPagoRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado")),
):
    pago = session.get(Pago, id_pago)

    if not pago:
        raise HTTPException(
            status_code=404,
            detail="Pago no encontrado."
        )

    estado_anterior = pago.estado
    pago.estado = datos.estado

    session.add(pago)
    session.commit()
    session.refresh(pago)

    registrar_bitacora(
        session=session,
        id_usuario=usuario_actual["usuario"].id_usuarios,
        modulo="HU-33 - Pagos del Proyecto",
        accion="Actualizar estado de pago",
        descripcion=f"Pago ID {id_pago}: {estado_anterior} -> {datos.estado}.",
    )

    # Notificar al cliente sobre la validación del pago en tiempo real
    if datos.estado in ["Completado", "Pagado", "Aprobado"]:
        try:
            from models import Proyecto
            from routers.notificaciones_app import enviar_notificacion_push
            proyecto = session.get(Proyecto, pago.id_proyecto)
            if proyecto and proyecto.id_usuarios:
                enviar_notificacion_push(
                    id_usuario=proyecto.id_usuarios,
                    titulo="¡Pago validado y confirmado!",
                    mensaje=f"Tu pago de {pago.monto} Bs. para la cuota '{pago.metodo_pago}' del proyecto '{proyecto.nombre}' ha sido verificado con éxito.",
                    data={"id_pago": str(id_pago), "tipo": "pago"}
                )
        except Exception as e:
            print(f"Error al enviar notificación de pago validado: {e}")

    return {
        "mensaje": "Estado del pago actualizado correctamente.",
        "pago": pago
    }


@router.post("/proyectos/solicitar")
def solicitar_proyecto(
    datos: SolicitarProyectoRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    cotizacion = session.get(Cotizacion, datos.id_cotizacion)
    if not cotizacion:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")

    # Crear proyecto en estado "Pendiente"
    proyecto = Proyecto(
        id_usuarios=cotizacion.id_usuarios,
        nombre=cotizacion.nombre or f"Proyecto - {cotizacion.ubicacion}",
        ubicacion=cotizacion.ubicacion,
        fecha_inicio=datetime.utcnow().date(),
        estado="Pendiente"
    )
    session.add(proyecto)
    session.commit()
    session.refresh(proyecto)

    # Actualizar cotización a aprobado
    cotizacion.estado = "Aprobado"
    session.add(cotizacion)
    session.commit()

    registrar_bitacora(
        session=session,
        id_usuario=usuario_actual["usuario"].id_usuarios,
        modulo="HU-33 - Pagos del Proyecto",
        accion="Solicitar proyecto",
        descripcion=f"Solicitud de proyecto ID {proyecto.id_proyecto} creada a partir de cotización {datos.id_cotizacion}."
    )

    return {
        "mensaje": "Solicitud de proyecto enviada correctamente. Esperando aprobación de la constructora.",
        "proyecto": proyecto
    }


@router.post("/proyectos/{id_proyecto}/establecer-plan")
def establecer_plan_pagos(
    id_proyecto: int,
    datos: EstablecerPlanRequest,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    proyecto = session.get(Proyecto, id_proyecto)
    if not proyecto:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")

    if proyecto.estado == "Pendiente":
        raise HTTPException(
            status_code=400,
            detail="El proyecto está pendiente de aprobación por la empresa constructora. Debe cambiar al estado 'En planificación' para establecer el plan de pagos."
        )

    # Verificar si ya tiene pagos creados
    existing_pagos = session.exec(
        select(Pago).where(Pago.id_proyecto == id_proyecto)
    ).all()
    if existing_pagos:
        raise HTTPException(status_code=400, detail="Este proyecto ya tiene un plan de pagos establecido.")

    # Buscar la última cotización para calcular el costo
    cotizacion = session.exec(
        select(Cotizacion)
        .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
        .order_by(col(Cotizacion.id_cotizacion).desc())
    ).first()
    if not cotizacion:
        raise HTTPException(status_code=404, detail="No se encontró cotización previa para calcular el costo.")

    total = Decimal(str(cotizacion.costo_estimado))

    if datos.tipo_plan == "directo":
      
        pago = Pago(
            id_proyecto=proyecto.id_proyecto,
           
            metodo_pago="Pago Directo",
            monto=total,
            fecha=datetime.utcnow(),
            estado="Pendiente",
            
        )
        session.add(pago)
    else:
        # 1. 5% Reserva (Se paga automáticamente al iniciar)
        reserva = redondear(total * Decimal("0.05"))
        
       
        pago_reserva = Pago(
            id_proyecto=proyecto.id_proyecto,
           
            metodo_pago="Reserva (5%)",
            monto=reserva,
            fecha=datetime.utcnow(),
            estado="Pendiente",
           
        )
        session.add(pago_reserva)

        # 2. Divide remaining 95%
        monto_restante = total - reserva
        cuotas = datos.cantidad_cuotas or 10
        monto_cuota = redondear(monto_restante / Decimal(str(cuotas)))

        for i in range(1, cuotas + 1):
            vencimiento = sumar_meses(datetime.utcnow(), i)
            pago_cuota = Pago(
                id_proyecto=proyecto.id_proyecto,
                metodo_pago=f"Cuota {i}",
                monto=monto_cuota,
                fecha=vencimiento,
                estado="Pendiente"
            )
            session.add(pago_cuota)

    session.commit()

    registrar_bitacora(
        session=session,
        id_usuario=usuario_actual["usuario"].id_usuarios,
        modulo="HU-33 - Pagos del Proyecto",
        accion="Establecer plan de pagos",
        descripcion=f"Establecido plan {datos.tipo_plan} para proyecto ID {id_proyecto}."
    )

    return {"mensaje": "Plan de pagos establecido correctamente."}


@router.get("/cliente/proyecto")
def obtener_proyecto_cliente(
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    usuario = usuario_actual["usuario"]
    proyecto = session.exec(
        select(Proyecto)
        .where(Proyecto.id_usuarios == usuario.id_usuarios)
        .order_by(col(Proyecto.id_proyecto).desc())
    ).first()

    if not proyecto:
        return {"tiene_proyecto": False}

    pagos = session.exec(
        select(Pago)
        .where(Pago.id_proyecto == proyecto.id_proyecto)
        .order_by(col(Pago.id_pago).asc())
    ).all()

    total_pagado = Decimal("0")
    total_pendiente = Decimal("0")
    total_estimado = Decimal("0")
    
    if pagos:
        for p in pagos:
            if p.estado in ["Completado", "Pagado", "Aprobado"]:
                total_pagado += p.monto
            else:
                total_pendiente += p.monto
        total_estimado = total_pagado + total_pendiente
    else:
        cotizacion = session.exec(
            select(Cotizacion)
            .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
            .order_by(col(Cotizacion.id_cotizacion).desc())
        ).first()
        if cotizacion:
            total_estimado = cotizacion.costo_estimado

    return {
        "tiene_proyecto": True,
        "proyecto": proyecto,
        "pagos": pagos,
        "total_pagado": redondear(total_pagado),
        "total_pendiente": redondear(total_pendiente),
        "total_estimado": redondear(total_estimado)
    }


@router.get("/cliente/proyectos")
def listar_proyectos_cliente(
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    usuario = usuario_actual["usuario"]
    proyectos = session.exec(
        select(Proyecto)
        .where(Proyecto.id_usuarios == usuario.id_usuarios)
        .order_by(col(Proyecto.id_proyecto).desc())
    ).all()
    
    resultado = []
    for p in proyectos:
        p_dict = p.dict()
        p_dict["ubicacion"] = limpiar_ubicacion(p.ubicacion)
        resultado.append(p_dict)
    return resultado


@router.get("/cliente/proyectos/{id_proyecto}")
def obtener_detalles_proyecto_cliente(
    id_proyecto: int,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    usuario = usuario_actual["usuario"]
    proyecto = session.get(Proyecto, id_proyecto)
    if not proyecto:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
        
    if usuario_actual["rol"] not in ["Administrador", "Empleado"] and proyecto.id_usuarios != usuario.id_usuarios:
        raise HTTPException(status_code=403, detail="No tienes acceso a este proyecto")
        
    pagos = session.exec(
        select(Pago)
        .where(Pago.id_proyecto == proyecto.id_proyecto)
        .order_by(col(Pago.id_pago).asc())
    ).all()

    total_pagado = Decimal("0")
    total_pendiente = Decimal("0")
    total_estimado = Decimal("0")
    # Buscar cotización asociada al proyecto (por usuario y ubicación)
    cotizacion = session.exec(
        select(Cotizacion)
        .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
        .where(Cotizacion.ubicacion == proyecto.ubicacion)
        .order_by(col(Cotizacion.id_cotizacion).desc())
    ).first()

    if not cotizacion:
        # Fallback a la última cotización del usuario si no coincide la ubicación exacta
        cotizacion = session.exec(
            select(Cotizacion)
            .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
            .order_by(col(Cotizacion.id_cotizacion).desc())
        ).first()

    if pagos:
        for p in pagos:
            if p.estado in ["Completado", "Pagado", "Aprobado"]:
                total_pagado += p.monto
            else:
                total_pendiente += p.monto
        total_estimado = total_pagado + total_pendiente
    else:
        if cotizacion:
            total_estimado = cotizacion.costo_estimado

    cotizacion_data = None
    if cotizacion:
        cotizacion_data = cotizacion.dict()
        if isinstance(cotizacion_data.get("ambientes"), str):
            cotizacion_data["ambientes"] = [
                amb.strip() for amb in cotizacion_data["ambientes"].split(",") if amb.strip()
            ]

    # Cargar nombres de empleados asignados y conteo de obreros
    from models import Empleados
    nom_ingeniero = "No asignado"
    nom_residente = "No asignado"
    nom_maestro = "No asignado"
    nom_albaniles = "No asignado"
    nom_ayudantes = "No asignado"

    if getattr(proyecto, "id_ingeniero", None):
        emp = session.get(Empleados, proyecto.id_ingeniero)
        if emp:
            nom_ingeniero = emp.nombre
    if getattr(proyecto, "id_residente", None):
        emp = session.get(Empleados, proyecto.id_residente)
        if emp:
            nom_residente = emp.nombre
    if getattr(proyecto, "id_maestro", None):
        emp = session.get(Empleados, proyecto.id_maestro)
        if emp:
            nom_maestro = emp.nombre

    id_albaniles_list = getattr(proyecto, "id_albaniles", None) or []
    albaniles_names = []
    for emp_id in id_albaniles_list:
        emp = session.get(Empleados, emp_id)
        if emp:
            albaniles_names.append(emp.nombre)
    if albaniles_names:
        nom_albaniles = ", ".join(albaniles_names)

    id_ayudantes_list = getattr(proyecto, "id_ayudantes", None) or []
    ayudantes_names = []
    for emp_id in id_ayudantes_list:
        emp = session.get(Empleados, emp_id)
        if emp:
            ayudantes_names.append(emp.nombre)
    if ayudantes_names:
        nom_ayudantes = ", ".join(ayudantes_names)

    cant_obreros = len(id_albaniles_list) + len(id_ayudantes_list)

    # Conteo de maquinaria asignada al proyecto
    from models import ActivosFijos
    cant_maquinaria = len(session.exec(
        select(ActivosFijos).where(ActivosFijos.id_proyecto == proyecto.id_proyecto)
    ).all())

    # Fetch latest progress from AvanceProyecto
    from models import AvanceProyecto, DocumentoProyecto, AvanceFoto
    latest_avance = session.exec(
        select(AvanceProyecto)
        .where(AvanceProyecto.id_proyecto == proyecto.id_proyecto)
        .order_by(col(AvanceProyecto.id_avance).desc())
    ).first()
    progreso_real = latest_avance.porcentaje_avance if latest_avance else 0

    proyecto_dict = proyecto.dict()
    proyecto_dict["ubicacion"] = limpiar_ubicacion(proyecto.ubicacion)
    proyecto_dict["nom_ingeniero"] = nom_ingeniero
    proyecto_dict["nom_residente"] = nom_residente
    proyecto_dict["nom_maestro"] = nom_maestro
    proyecto_dict["nom_albaniles"] = nom_albaniles
    proyecto_dict["nom_ayudantes"] = nom_ayudantes
    proyecto_dict["cant_obreros"] = cant_obreros
    proyecto_dict["cant_maquinaria"] = cant_maquinaria
    proyecto_dict["porcentaje_avance"] = progreso_real

    # Fetch documents and photos associated with this project
    documentos = session.exec(
        select(DocumentoProyecto)
        .where(DocumentoProyecto.id_proyecto == proyecto.id_proyecto)
    ).all()

    advances = session.exec(
        select(AvanceProyecto)
        .where(AvanceProyecto.id_proyecto == proyecto.id_proyecto)
    ).all()
    
    fotos = []
    if advances:
        advance_ids = [adv.id_avance for adv in advances]
        fotos = session.exec(
            select(AvanceFoto)
            .where(col(AvanceFoto.id_avance).in_(advance_ids))
        ).all()

    return {
        "proyecto": proyecto_dict,
        "pagos": pagos,
        "total_pagado": redondear(total_pagado),
        "total_pendiente": redondear(total_pendiente),
        "total_estimado": redondear(total_estimado),
        "cotizacion": cotizacion_data,
        "documentos": documentos,
        "fotos": [f.ruta_foto for f in fotos]
    }


@router.post("/pagos/{id_pago}/pagar")
def registrar_pago_cuota(
    id_pago: int,
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    pago = session.get(Pago, id_pago)
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")

    if pago.estado in ["Completado", "Pagado", "Aprobado"]:
        return {"mensaje": "El pago ya fue completado", "pago": pago}

    pago.estado = "Completado"
    pago.fecha = datetime.utcnow()
    pago.codigo_transaccion = f"TX-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

    # Register financial movement
    movimiento = MovimientoFinanciero(
        id_proyecto=pago.id_proyecto,
        tipo_movimiento="Ingreso",
        categoria="Pago de proyecto",
        monto=pago.monto,
        fecha=datetime.utcnow().date(),
        descripcion=f"Pago '{pago.metodo_pago}' para el proyecto ID {pago.id_proyecto}"
    )
    session.add(movimiento)
    session.commit()
    session.refresh(movimiento)

    pago.id_movimiento = movimiento.id_movimiento
    session.add(pago)
    session.commit()
    session.refresh(pago)

    registrar_bitacora(
        session=session,
        id_usuario=usuario_actual["usuario"].id_usuarios,
        modulo="HU-33 - Pagos del Proyecto",
        accion="Pagar cuota",
        descripcion=f"Cuota {id_pago} de {pago.monto} Bs pagada para proyecto {pago.id_proyecto}."
    )

    # Notificar al cliente sobre el registro de su pago
    try:
        from models import Proyecto
        from routers.notificaciones_app import enviar_notificacion_push
        proyecto = session.get(Proyecto, pago.id_proyecto)
        if proyecto and proyecto.id_usuarios:
            enviar_notificacion_push(
                id_usuario=proyecto.id_usuarios,
                titulo="Confirmación de pago recibida",
                mensaje=f"Tu pago de {pago.monto} Bs. para la cuota '{pago.metodo_pago}' del proyecto '{proyecto.nombre}' ha sido registrado con éxito.",
                data={"id_pago": str(id_pago), "tipo": "pago"}
            )
    except Exception as e:
        print(f"Error al enviar notificación de pago registrado: {e}")

    return {
        "mensaje": "Pago registrado con éxito.",
        "pago": pago,
        "movimiento": movimiento
    }


@router.get("/proyectos/estado-financiero")
def listar_proyectos_estado_financiero(
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado")),
):
    from models import Usuario, Empleados

    proyectos = session.exec(select(Proyecto)).all()

    resultado = []
    for proyecto in proyectos:
        cliente_nombre = "Desconocido"
        if proyecto.id_usuarios:
            cliente = session.get(Usuario, proyecto.id_usuarios)
            if cliente:
                nombres = cliente.nombres or ""
                apellidos = cliente.apellido or ""
                nombre_completo = f"{nombres} {apellidos}".strip()
                cliente_nombre = nombre_completo if nombre_completo else cliente.nombresusuario

        pagos = session.exec(
            select(Pago).where(Pago.id_proyecto == proyecto.id_proyecto)
        ).all()

        total_contrato = Decimal("0")
        total_pagado = Decimal("0")
        
        if pagos:
            for p in pagos:
                total_contrato += p.monto
                if p.estado in ["Completado", "Pagado", "Aprobado"]:
                    total_pagado += p.monto
            saldo_pendiente = total_contrato - total_pagado
        else:
            # Query associated quote
            cotizacion = session.exec(
                select(Cotizacion)
                .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
                .where(Cotizacion.ubicacion == proyecto.ubicacion)
                .order_by(col(Cotizacion.id_cotizacion).desc())
            ).first()
            if not cotizacion:
                cotizacion = session.exec(
                    select(Cotizacion)
                    .where(Cotizacion.id_usuarios == proyecto.id_usuarios)
                    .order_by(col(Cotizacion.id_cotizacion).desc())
                ).first()
            if cotizacion:
                total_contrato = Decimal(str(cotizacion.costo_estimado))
            saldo_pendiente = total_contrato

        # Convert values to Bolivianos (Bs) by multiplying by the exchange rate 6.96
        TASA_CAMBIO = Decimal("6.96")
        total_contrato_bob = total_contrato * TASA_CAMBIO
        total_pagado_bob = total_pagado * TASA_CAMBIO
        saldo_pendiente_bob = saldo_pendiente * TASA_CAMBIO

        if total_contrato_bob == 0:
            estado_pago = "Sin plan de pagos"
        elif saldo_pendiente_bob <= 0:
            estado_pago = "Finalizado"
        else:
            estado_pago = "Pendiente"

        nom_ingeniero = "No asignado"
        nom_residente = "No asignado"
        nom_maestro = "No asignado"
        nom_albaniles = "No asignado"
        nom_ayudantes = "No asignado"

        if getattr(proyecto, "id_ingeniero", None):
            emp = session.get(Empleados, proyecto.id_ingeniero)
            if emp:
                nom_ingeniero = emp.nombre
        if getattr(proyecto, "id_residente", None):
            emp = session.get(Empleados, proyecto.id_residente)
            if emp:
                nom_residente = emp.nombre
        if getattr(proyecto, "id_maestro", None):
            emp = session.get(Empleados, proyecto.id_maestro)
            if emp:
                nom_maestro = emp.nombre

        id_albaniles_list = getattr(proyecto, "id_albaniles", None) or []
        if id_albaniles_list:
            albaniles_names = []
            for emp_id in id_albaniles_list:
                emp = session.get(Empleados, emp_id)
                if emp:
                    albaniles_names.append(emp.nombre)
            if albaniles_names:
                nom_albaniles = ", ".join(albaniles_names)

        id_ayudantes_list = getattr(proyecto, "id_ayudantes", None) or []
        if id_ayudantes_list:
            ayudantes_names = []
            for emp_id in id_ayudantes_list:
                emp = session.get(Empleados, emp_id)
                if emp:
                    ayudantes_names.append(emp.nombre)
            if ayudantes_names:
                nom_ayudantes = ", ".join(ayudantes_names)

        resultado.append({
            "id_proyecto": proyecto.id_proyecto,
            "nombre": proyecto.nombre,
            "cliente": cliente_nombre,
            "ubicacion": limpiar_ubicacion(proyecto.ubicacion),
            "fecha_inicio": proyecto.fecha_inicio,
            "fecha_fin": proyecto.fecha_fin,
            "estado_proyecto": proyecto.estado,
            "total_contrato": redondear(total_contrato_bob),
            "total_pagado": redondear(total_pagado_bob),
            "saldo_pendiente": redondear(saldo_pendiente_bob),
            "estado_pago": estado_pago,
            "debe_dinero": saldo_pendiente_bob > 0 and total_contrato_bob > 0,
            "proyecto_finalizado": proyecto.estado.lower() in ["finalizado", "completado", "terminado"],
            "id_ingeniero": getattr(proyecto, "id_ingeniero", None),
            "id_residente": getattr(proyecto, "id_residente", None),
            "id_maestro": getattr(proyecto, "id_maestro", None),
            "id_albaniles": id_albaniles_list,
            "id_ayudantes": id_ayudantes_list,
            "nom_ingeniero": nom_ingeniero,
            "nom_residente": nom_residente,
            "nom_maestro": nom_maestro,
            "nom_albaniles": nom_albaniles,
            "nom_ayudantes": nom_ayudantes,
        })

    return resultado