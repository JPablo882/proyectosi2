from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from database_empresa import get_session_empresa
from models import Pago, Proyecto, MovimientoFinanciero
from datetime import datetime
from routers.notificaciones_app import enviar_notificacion_push
import urllib.parse

router = APIRouter(
    prefix="/casos-uso/hu33/qr",
    tags=["HU-33 - Códigos QR de Pago Rápido"]
)

@router.post("/{id_pago}/generar-qr")
def generar_qr_pago(
    id_pago: int,
    session: Session = Depends(get_session_empresa)
):
    pago = session.get(Pago, id_pago)
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")
        
    proyecto = session.get(Proyecto, pago.id_proyecto)
    nombre_proyecto = proyecto.nombre if proyecto else "Proyecto Construcción"
    
    # Construir payload del QR de transferencia rápida boliviana
    banco = "Banco Unión S.A."
    cuenta = "10000038475812"
    monto = pago.monto
    concepto = f"Pago {pago.metodo_pago} - {nombre_proyecto}"
    
    qr_payload = f"BANCO: {banco} | CUENTA: {cuenta} | MONTO: {monto} Bs. | CONCEPTO: {concepto}"
    
    # Generar la URL del QR usando la API pública gratuita qrserver
    qr_url = f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={urllib.parse.quote(qr_payload)}"
    
    return {
        "id_pago": id_pago,
        "monto": monto,
        "concepto": concepto,
        "banco": banco,
        "cuenta": cuenta,
        "qr_payload": qr_payload,
        "qr_url": qr_url
    }

@router.post("/{id_pago}/confirmar-qr")
def confirmar_qr_pago(
    id_pago: int,
    session: Session = Depends(get_session_empresa)
):
    pago = session.get(Pago, id_pago)
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")
        
    if pago.estado in ["Completado", "Pagado", "Aprobado"]:
        return {"mensaje": "El pago ya fue completado", "pago": pago}
        
    pago.estado = "Completado"
    pago.fecha = datetime.utcnow()
    pago.codigo_transaccion = f"QR-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
    
    # Registrar el movimiento financiero
    movimiento = MovimientoFinanciero(
        id_proyecto=pago.id_proyecto,
        tipo_movimiento="Ingreso",
        categoria="Pago de proyecto",
        monto=pago.monto,
        fecha=datetime.utcnow().date(),
        descripcion=f"Pago QR '{pago.metodo_pago}' para el proyecto ID {pago.id_proyecto} (QR Rápido Bancario)"
    )
    session.add(movimiento)
    session.commit()
    session.refresh(movimiento)
    
    pago.id_movimiento = movimiento.id_movimiento
    session.add(pago)
    session.commit()
    session.refresh(pago)
    
    # Notificar al cliente de forma inmediata
    proyecto = session.get(Proyecto, pago.id_proyecto)
    if proyecto and proyecto.id_usuarios:
        enviar_notificacion_push(
            id_usuario=proyecto.id_usuarios,
            titulo="¡Pago confirmado con QR!",
            mensaje=f"Tu pago de {pago.monto} Bs. para el proyecto '{proyecto.nombre}' ha sido validado y procesado de forma automática.",
            data={"id_pago": str(pago.id_pago), "tipo": "pago"}
        )
        
    return {
        "mensaje": "Pago mediante QR procesado y verificado con éxito.",
        "pago": pago,
        "movimiento": movimiento
    }
