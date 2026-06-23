import os
import re
import json
import uuid
from pathlib import Path
from decimal import Decimal

from fastapi import APIRouter, HTTPException, UploadFile, File, Depends
from pydantic import BaseModel, Field
from sqlmodel import Session, select, col
from sqlalchemy import func
from google import genai

from utils.ia_gemini import responder_con_gemini
from utils.transcripcion_audio import transcribir_audio

from database_empresa import get_session_empresa
from models import (
    Proyecto,
    Material,
    Presupuesto,
    MovimientoFinanciero,
    Planillas,
    ActivosFijos,
    Empleados,
    Cliente,
    Venta,
    Pago,
    Compra,
    Proveedor,
    DetalleCompra,
)


router = APIRouter(
    prefix="/ia",
    tags=["IA - Gemini y Audio"]
)


# ============================================================
# MODELOS DE REQUEST / RESPONSE
# ============================================================

class PreguntaIARequest(BaseModel):
    pregunta: str = Field(..., min_length=2)


class PreguntaIAResponse(BaseModel):
    tipo: str
    pregunta: str
    respuesta: str


class AudioIAResponse(BaseModel):
    tipo: str
    transcripcion: str
    respuesta: str


from typing import Optional, List, Dict, Any

class PreguntaIAContextoRequest(BaseModel):
    pregunta: str = Field(..., min_length=2)
    historial: Optional[List[Dict[str, Any]]] = Field(default_factory=list)


class PreguntaIAContextoResponse(BaseModel):
    tipo: str
    pregunta: str
    contexto_usado: str
    respuesta: str


class AudioIAContextoResponse(BaseModel):
    tipo: str
    transcripcion: str
    contexto_usado: str
    respuesta: str


# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

def redondear_valor(valor) -> str:
    if valor is None:
        return "0.00"

    try:
        return str(Decimal(str(valor)).quantize(Decimal("0.01")))
    except Exception:
        return str(valor)


def construir_contexto_empresa(session: Session) -> str:
    # ============================================================
    # RESUMEN GENERAL
    # ============================================================

    total_proyectos = session.exec(
        select(func.count(col(Proyecto.id_proyecto)))
    ).one()

    total_materiales = session.exec(
        select(func.count(col(Material.id_material)))
    ).one()

    total_empleados = session.exec(
        select(func.count(col(Empleados.id_empleados)))
    ).one()

    total_clientes = session.exec(
        select(func.count(col(Cliente.id_cliente)))
    ).one()

    total_proveedores = session.exec(
        select(func.count(col(Proveedor.id_proveedor)))
    ).one()

    total_presupuestado = session.exec(
        select(func.coalesce(func.sum(col(Presupuesto.costo_total)), 0))
    ).one()

    total_ingresos = session.exec(
        select(func.coalesce(func.sum(col(MovimientoFinanciero.monto)), 0))
        .where(func.lower(col(MovimientoFinanciero.tipo_movimiento)) == "ingreso")
    ).one()

    total_egresos = session.exec(
        select(func.coalesce(func.sum(col(MovimientoFinanciero.monto)), 0))
        .where(func.lower(col(MovimientoFinanciero.tipo_movimiento)) == "egreso")
    ).one()

    total_planillas = session.exec(
        select(func.coalesce(func.sum(col(Planillas.pago)), 0))
    ).one()

    valor_activos = session.exec(
        select(func.coalesce(func.sum(col(ActivosFijos.valor_compra)), 0))
    ).one()

    total_ventas = session.exec(
        select(func.coalesce(func.sum(col(Venta.total)), 0))
    ).one()

    total_compras = session.exec(
        select(func.coalesce(func.sum(col(Compra.total)), 0))
    ).one()

    total_pagos = session.exec(
        select(func.coalesce(func.sum(col(Pago.monto)), 0))
    ).one()

    pagos_pendientes = session.exec(
        select(func.coalesce(func.sum(col(Pago.monto)), 0))
        .where(func.lower(col(Pago.estado)) == "pendiente")
    ).one()

    pagos_completados = session.exec(
        select(func.coalesce(func.sum(col(Pago.monto)), 0))
        .where(func.lower(col(Pago.estado)) == "completado")
    ).one()

    # ============================================================
    # LISTAS PRINCIPALES
    # ============================================================

    proyectos = session.exec(
        select(Proyecto).limit(5)
    ).all()

    materiales_principales = session.exec(
        select(Material)
        .order_by(col(Material.stock))
        .limit(5)
    ).all()

    materiales_bajo_stock = session.exec(
        select(Material)
        .where(Material.stock <= 10)
        .order_by(col(Material.stock))
        .limit(5)
    ).all()

    activos = session.exec(
        select(ActivosFijos).limit(5)
    ).all()

    clientes = session.exec(
        select(Cliente).limit(5)
    ).all()

    proveedores = session.exec(
        select(Proveedor).limit(5)
    ).all()

    ventas = session.exec(
        select(Venta)
        .order_by(col(Venta.fecha).asc())
        .limit(5)
    ).all()

    compras = session.exec(
        select(Compra)
        .order_by(col(Compra.fecha).asc())
        .limit(5)
    ).all()

    pagos = session.exec(
        select(Pago)
        .order_by(col(Pago.fecha).asc())
        .limit(5)
    ).all()

    detalles_compra = session.exec(
        select(DetalleCompra).limit(5)
    ).all()

    # ============================================================
    # FORMATEO DE LISTAS
    # ============================================================

    lista_proyectos = "\n".join(
        [
            f"- ID {p.id_proyecto}: {p.nombre}, ubicación: {p.ubicacion}, estado: {p.estado}"
            for p in proyectos
        ]
    ) or "No hay proyectos registrados."

    lista_materiales = "\n".join(
        [
            f"- ID {m.id_material}: {m.nombre}, stock: {m.stock}, precio: {m.precio} Bs"
            for m in materiales_principales
        ]
    ) or "No hay materiales registrados."

    lista_materiales_bajo_stock = "\n".join(
        [
            f"- {m.nombre}: stock {m.stock}, precio {m.precio} Bs"
            for m in materiales_bajo_stock
        ]
    ) or "No hay materiales con stock bajo."

    lista_activos = "\n".join(
        [
            f"- ID {a.id_activo}: {a.nombre}, tipo: {a.tipo_activo}, valor compra: {a.valor_compra} Bs, estado: {a.estado}"
            for a in activos
        ]
    ) or "No hay activos fijos registrados."

    lista_clientes = "\n".join(
        [
            f"- ID {c.id_cliente}: {c.nombre}, teléfono: {c.telefono}, dirección: {c.direccion}"
            for c in clientes
        ]
    ) or "No hay clientes registrados."

    lista_proveedores = "\n".join(
        [
            f"- ID {p.id_proveedor}: {p.nombre}, contacto: {p.contacto}"
            for p in proveedores
        ]
    ) or "No hay proveedores registrados."

    lista_ventas = "\n".join(
        [
            f"- ID {v.id_venta}: cliente ID {v.id_cliente}, total: {v.total} Bs, fecha: {v.fecha}"
            for v in ventas
        ]
    ) or "No hay ventas registradas."

    lista_compras = "\n".join(
        [
            f"- ID {c.id_compra}: proveedor ID {c.id_proveedor}, total: {c.total} Bs, fecha: {c.fecha}"
            for c in compras
        ]
    ) or "No hay compras registradas."

    lista_pagos = "\n".join(
        [
            f"- ID {p.id_pago}: proyecto ID {p.id_proyecto}, monto: {p.monto} Bs, estado: {p.estado}, método: {p.metodo_pago}, fecha: {p.fecha}"
            for p in pagos
        ]
    ) or "No hay pagos registrados."

    lista_detalle_compras = []

    for detalle in detalles_compra:
        material = session.get(Material, detalle.id_material)
        compra = session.get(Compra, detalle.id_compra)

        nombre_material = material.nombre if material else f"Material ID {detalle.id_material}"
        id_compra = compra.id_compra if compra else detalle.id_compra

        lista_detalle_compras.append(
            f"- Compra ID {id_compra}: {nombre_material}, cantidad: {detalle.cantidad}, precio: {detalle.precio} Bs"
        )

    lista_detalle_compras = "\n".join(lista_detalle_compras) or "No hay detalles de compra registrados."

    # ============================================================
    # CONTEXTO FINAL PARA GEMINI
    # ============================================================

    contexto = f"""
DATOS ACTUALES DE LA EMPRESA

Resumen general:
- Total de proyectos: {total_proyectos}
- Total de materiales: {total_materiales}
- Total de empleados: {total_empleados}
- Total de clientes: {total_clientes}
- Total de proveedores: {total_proveedores}
- Total presupuestado: {redondear_valor(total_presupuestado)} Bs
- Total ingresos: {redondear_valor(total_ingresos)} Bs
- Total egresos: {redondear_valor(total_egresos)} Bs
- Total planillas: {redondear_valor(total_planillas)} Bs
- Valor total de activos fijos: {redondear_valor(valor_activos)} Bs
- Total ventas: {redondear_valor(total_ventas)} Bs
- Total compras: {redondear_valor(total_compras)} Bs
- Total pagos registrados: {redondear_valor(total_pagos)} Bs
- Pagos pendientes: {redondear_valor(pagos_pendientes)} Bs
- Pagos completados: {redondear_valor(pagos_completados)} Bs

Proyectos registrados:
{lista_proyectos}

Materiales principales:
{lista_materiales}

Materiales con stock bajo:
{lista_materiales_bajo_stock}

Activos fijos:
{lista_activos}

Clientes:
{lista_clientes}

Proveedores:
{lista_proveedores}

Ventas recientes:
{lista_ventas}

Compras recientes:
{lista_compras}

Pagos recientes:
{lista_pagos}

Detalle de compras:
{lista_detalle_compras}
"""

    return contexto


def generar_respuesta_local_de_respaldo(pregunta: str, contexto: str, error_msg: str) -> str:
    texto_pregunta = pregunta.lower()
    
    # Intentar extraer datos del contexto usando regex
    total_materiales = re.search(r"- Total de materiales:\s*(\d+)", contexto)
    total_proyectos = re.search(r"- Total de proyectos:\s*(\d+)", contexto)
    total_empleados = re.search(r"- Total de empleados:\s*(\d+)", contexto)
    total_clientes = re.search(r"- Total de clientes:\s*(\d+)", contexto)
    total_ingresos = re.search(r"- Total ingresos:\s*([^\n]+)", contexto)
    total_egresos = re.search(r"- Total egresos:\s*([^\n]+)", contexto)
    
    mat_count = total_materiales.group(1) if total_materiales else "0"
    proj_count = total_proyectos.group(1) if total_proyectos else "0"
    emp_count = total_empleados.group(1) if total_empleados else "0"
    cli_count = total_clientes.group(1) if total_clientes else "0"
    ingresos = total_ingresos.group(1).strip() if total_ingresos else "0.00 Bs"
    egresos = total_egresos.group(1).strip() if total_egresos else "0.00 Bs"

    # Extraer la lista de proyectos
    proyectos_match = re.search(r"Proyectos registrados:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_proyectos = proyectos_match.group(1).strip() if proyectos_match else ""
    
    # Extraer la lista de materiales bajo stock
    stock_match = re.search(r"Materiales con stock bajo:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_stock_bajo = stock_match.group(1).strip() if stock_match else ""

    # Extraer la lista de clientes
    clientes_match = re.search(r"Clientes:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_clientes = clientes_match.group(1).strip() if clientes_match else ""

    # Extraer la lista de proveedores
    proveedores_match = re.search(r"Proveedores:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_proveedores = proveedores_match.group(1).strip() if proveedores_match else ""

    # Extraer la lista de compras
    compras_match = re.search(r"Compras recientes:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_compras = compras_match.group(1).strip() if compras_match else ""

    # Extraer la lista de pagos
    pagos_match = re.search(r"Pagos recientes:\n(.*?)(?=\n\n|\n[A-Z]|$)", contexto, re.DOTALL)
    lista_pagos = pagos_match.group(1).strip() if pagos_match else ""

    explicacion_error = ""
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if api_key.startswith("AQ."):
        explicacion_error = (
            "\n\n*(Nota de la IA de respaldo: Detectamos que tu API Key inicia con **'AQ.'**. "
            "Google AI Studio restringe las claves cuando detecta advertencias de seguridad en la cuenta. "
            "Por este motivo, Gemini ha denegado la solicitud. Sin embargo, he procesado tu consulta directamente con "
            "los datos locales de la base de datos).* "
        )
    else:
        explicacion_error = f"\n\n*(Nota de la IA de respaldo: Ocurrió un error al conectar con Gemini: {error_msg}. Mostrando datos locales).* "

    # Respuestas heurísticas
    if any(p in texto_pregunta for p in ["material", "stock", "inventario"]):
        msg = (
            f"Hola. Actualmente tienes un total de **{mat_count} materiales** registrados en el inventario de tu empresa.\n\n"
            f"**Materiales con stock bajo (menor o igual a 10 unidades):**\n{lista_stock_bajo}\n"
            f"{explicacion_error}"
        )
        return msg
        
    elif any(p in texto_pregunta for p in ["proyecto", "obra"]):
        msg = (
            f"Hola. Tienes **{proj_count} proyectos** activos o en planificación en la empresa.\n\n"
            f"**Lista de proyectos actuales:**\n{lista_proyectos}\n"
            f"{explicacion_error}"
        )
        return msg

    elif any(p in texto_pregunta for p in ["cliente"]):
        msg = (
            f"Hola. Tienes **{cli_count} clientes** registrados en la empresa.\n\n"
            f"**Lista de clientes registrados:**\n{lista_clientes}\n"
            f"{explicacion_error}"
        )
        return msg

    elif any(p in texto_pregunta for p in ["proveedor"]):
        msg = (
            f"Hola. Tienes proveedores registrados en el sistema.\n\n"
            f"**Lista de proveedores:**\n{lista_proveedores}\n"
            f"{explicacion_error}"
        )
        return msg
        
    elif any(p in texto_pregunta for p in ["empleado", "rrhh", "trabajador", "personal"]):
        msg = (
            f"Hola. Tienes un total de **{emp_count} empleados** registrados trabajando en tus obras.\n"
            f"{explicacion_error}"
        )
        return msg
        
    elif any(p in texto_pregunta for p in ["compra", "compras", "egreso", "egresos"]):
        msg = (
            f"Hola. Aquí tienes las compras y egresos recientes de la empresa:\n\n"
            f"**Historial de compras:**\n{lista_compras}\n\n"
            f"**Egresos Totales:** {egresos}\n"
            f"{explicacion_error}"
        )
        return msg

    elif any(p in texto_pregunta for p in ["pago", "pagos", "ingreso", "ingresos"]):
        msg = (
            f"Hola. Aquí tienes el historial de pagos y cobros registrados:\n\n"
            f"**Pagos recientes:**\n{lista_pagos}\n\n"
            f"**Ingresos Totales:** {ingresos}\n"
            f"{explicacion_error}"
        )
        return msg

    elif any(p in texto_pregunta for p in ["dinero", "caja", "financiero", "saldo", "presupuestado"]):
        msg = (
            f"Resumen financiero de la empresa:\n"
            f"- **Ingresos totales:** {ingresos}\n"
            f"- **Egresos totales:** {egresos}\n"
            f"*(Nota: Puedes ver detalles más avanzados en la sección de Reportes de tu panel de administración)*\n"
            f"{explicacion_error}"
        )
        return msg
        
    else:
        # Respuesta genérica con resumen general de la empresa
        msg = (
            f"Hola. He consultado el estado actual de tu empresa en el sistema:\n\n"
            f"- **Proyectos:** {proj_count} registrados.\n"
            f"- **Materiales en inventario:** {mat_count} registrados.\n"
            f"- **Empleados:** {emp_count} activos.\n"
            f"- **Clientes:** {cli_count} registrados.\n"
            f"- **Balance:** {ingresos} de ingresos y {egresos} de egresos.\n\n"
            f"¿Deseas saber detalles específicos de alguna de estas áreas?\n"
            f"{explicacion_error}"
        )
        return msg


def responder_con_contexto_empresa(pregunta: str, session: Session, historial: list = None) -> tuple[str, str]:
    contexto_empresa = construir_contexto_empresa(session)

    prompt = f"""
Eres un asistente inteligente para un sistema multiempresa de construcción.

Debes responder en español, de forma clara, útil y directa.

Tienes dos funciones:
1. Si la pregunta es general, responde normalmente.
2. Si la pregunta trata sobre la empresa, proyectos, materiales, presupuestos, empleados, activos, stock, compras, egresos o ingresos, usa estrictamente los datos reales entregados desde PostgreSQL.

No inventes datos que no estén en el contexto.
Si un dato no existe o no está registrado, dilo claramente.
Si los valores están en cero, explica que aún no existen registros suficientes.

Contexto real de la empresa:
{contexto_empresa}

Pregunta del usuario:
{pregunta}
"""

    try:
        respuesta = responder_con_gemini(prompt, historial)
    except Exception as e:
        print(f"Error llamando a Gemini: {e}. Usando respuesta local de respaldo.")
        respuesta = generar_respuesta_local_de_respaldo(pregunta, contexto_empresa, str(e))

    return contexto_empresa, respuesta


async def guardar_audio_temporal(audio: UploadFile) -> Path:
    extensiones_permitidas = [".mp3", ".wav", ".m4a", ".ogg", ".webm", ".mp4"]

    nombre_original = audio.filename or ""
    extension = Path(nombre_original).suffix.lower()

    if extension not in extensiones_permitidas:
        raise HTTPException(
            status_code=400,
            detail="Formato de audio no permitido. Usa mp3, wav, m4a, ogg, webm o mp4."
        )

    carpeta_temporal = Path("temp_audio")
    carpeta_temporal.mkdir(exist_ok=True)

    nombre_temporal = f"{uuid.uuid4()}{extension}"
    ruta_temporal = carpeta_temporal / nombre_temporal

    contenido = await audio.read()

    if not contenido:
        raise HTTPException(
            status_code=400,
            detail="El archivo de audio está vacío."
        )

    with open(ruta_temporal, "wb") as archivo:
        archivo.write(contenido)

    return ruta_temporal


# ============================================================
# 1. IA GENERAL POR TEXTO
# ============================================================

@router.post("/preguntar", response_model=PreguntaIAResponse)
def preguntar_ia(datos: PreguntaIARequest):
    try:
        respuesta = responder_con_gemini(datos.pregunta)

        return {
            "tipo": "texto",
            "pregunta": datos.pregunta,
            "respuesta": respuesta
        }

    except Exception as error:
        api_key = os.getenv("GEMINI_API_KEY", "").strip()
        if api_key.startswith("AQ."):
            msg_error = (
                "Hola. Actualmente la clave de API de Gemini inicia con 'AQ.'. "
                "Google AI Studio restringe las claves de esta forma cuando detecta advertencias de seguridad/políticas en la cuenta, "
                "por lo que no se pueden usar en llamadas de API estándar. "
                "Para solucionarlo, debes generar una nueva API Key en Google AI Studio usando una cuenta de Google diferente."
            )
            return {
                "tipo": "texto",
                "pregunta": datos.pregunta,
                "respuesta": msg_error
            }
        else:
            raise HTTPException(
                status_code=500,
                detail=f"Error al consultar Gemini: {str(error)}"
            )


# ============================================================
# 2. IA GENERAL POR AUDIO
# ============================================================

@router.post("/preguntar-audio", response_model=AudioIAResponse)
async def preguntar_ia_con_audio(audio: UploadFile = File(...)):
    ruta_temporal = None

    try:
        ruta_temporal = await guardar_audio_temporal(audio)

        transcripcion = transcribir_audio(str(ruta_temporal))

        if not transcripcion or transcripcion == "No se pudo transcribir el audio.":
            raise HTTPException(
                status_code=400,
                detail="No se pudo transcribir el audio."
            )

        pregunta_para_ia = f"""
El usuario envió un audio. Esta es la transcripción:

{transcripcion}

Responde a lo que el usuario pidió en el audio.
"""

        respuesta = responder_con_gemini(pregunta_para_ia)

        return {
            "tipo": "audio",
            "transcripcion": transcripcion,
            "respuesta": respuesta
        }

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Error al procesar el audio con IA: {str(error)}"
        )

    finally:
        if ruta_temporal and ruta_temporal.exists():
            try:
                os.remove(ruta_temporal)
            except Exception:
                pass


# ============================================================
# 3. IA CON DATOS DE LA EMPRESA POR TEXTO
# ============================================================

@router.post("/preguntar-contexto", response_model=PreguntaIAContextoResponse)
def preguntar_ia_con_contexto(
    datos: PreguntaIAContextoRequest,
    session: Session = Depends(get_session_empresa),
):
    try:
        contexto_empresa, respuesta = responder_con_contexto_empresa(
            pregunta=datos.pregunta,
            session=session,
            historial=datos.historial
        )

        return {
            "tipo": "texto_con_contexto_empresa",
            "pregunta": datos.pregunta,
            "contexto_usado": "Datos consultados desde PostgreSQL según X-Empresa-Id.",
            "respuesta": respuesta,
        }

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Error al consultar IA con contexto de empresa: {str(error)}"
        )


# ============================================================
# 4. IA CON DATOS DE LA EMPRESA POR AUDIO
# ============================================================

@router.post("/preguntar-audio-contexto", response_model=AudioIAContextoResponse)
async def preguntar_ia_con_audio_contexto(
    audio: UploadFile = File(...),
    session: Session = Depends(get_session_empresa),
):
    ruta_temporal = None

    try:
        ruta_temporal = await guardar_audio_temporal(audio)

        transcripcion = transcribir_audio(str(ruta_temporal))

        if not transcripcion or transcripcion == "No se pudo transcribir el audio.":
            raise HTTPException(
                status_code=400,
                detail="No se pudo transcribir el audio."
            )

        contexto_empresa, respuesta = responder_con_contexto_empresa(
            pregunta=transcripcion,
            session=session,
        )

        return {
            "tipo": "audio_con_contexto_empresa",
            "transcripcion": transcripcion,
            "contexto_usado": "Datos consultados desde PostgreSQL según X-Empresa-Id.",
            "respuesta": respuesta,
        }

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Error al procesar audio con contexto de empresa: {str(error)}"
        )

    finally:
        if ruta_temporal and ruta_temporal.exists():
            try:
                os.remove(ruta_temporal)
            except Exception:
                pass


# ============================================================
# 5. IA COTIZADOR DE OBRA POR AUDIO (FLUTTER APP)
# ============================================================



class CotizarAudioResponse(BaseModel):
    transcripcion: str
    ubicacion: str
    m2_terreno: int
    m2_construir: int
    habitaciones: int
    banos: int
    calidad_materiales: str
    ambientes: list[str]
    adicionales: str


def heuristica_extraer_datos(transcripcion: str, resultado: dict) -> dict:
    texto = transcripcion.lower()
    
    # Calidad de materiales
    if any(palabra in texto for palabra in ["lujo", "lujoso", "marmol", "mármol", "exclusivo", "gama alta"]):
        resultado["calidad_materiales"] = "Lujo"
    elif any(palabra in texto for palabra in ["premium", "porcelanato", "fino", "buena calidad"]):
        resultado["calidad_materiales"] = "Premium"
    else:
        resultado["calidad_materiales"] = "Estándar"
        
    # Ubicación
    match_ubi = re.search(r"(?:en|para|hacia)\s+([a-zA-Z\s]{3,20})(?:\s+de|\s+con|\.|\,|$)", transcripcion)
    if match_ubi:
        resultado["ubicacion"] = match_ubi.group(1).strip().capitalize()
        
    # Buscar números para m2 de construcción y terreno
    numeros = re.findall(r"\d+", texto)
    if numeros:
        match_m2 = re.findall(r"(\d+)\s*(?:m2|metros|m²)", texto)
        if len(match_m2) >= 1:
            resultado["m2_construir"] = int(match_m2[0])
            if len(match_m2) >= 2:
                resultado["m2_terreno"] = int(match_m2[1])
        else:
            nums_int = [int(n) for n in numeros]
            m2_candidatos = [n for n in nums_int if n >= 30 and n <= 1000]
            if m2_candidatos:
                resultado["m2_construir"] = m2_candidatos[0]
                
    # Habitaciones
    match_hab = re.search(r"(\d+)\s*(?:habitación|habitacion|dormitorio|cuarto|pieza|cama)", texto)
    if match_hab:
        resultado["habitaciones"] = int(match_hab.group(1))
    else:
        if "un cuarto" in texto or "una habitacion" in texto or "un dormitorio" in texto:
            resultado["habitaciones"] = 1
        elif "dos cuartos" in texto or "dos habitaciones" in texto or "dos dormitorios" in texto:
            resultado["habitaciones"] = 2
        elif "tres cuartos" in texto or "tres habitaciones" in texto or "tres dormitorios" in texto:
            resultado["habitaciones"] = 3
        elif "cuatro cuartos" in texto or "cuatro habitaciones" in texto or "cuatro dormitorios" in texto:
            resultado["habitaciones"] = 4

    # Baños
    match_ban = re.search(r"(\d+)\s*(?:baño|bano)", texto)
    if match_ban:
        resultado["banos"] = int(match_ban.group(1))
    else:
        if "un baño" in texto or "un bano" in texto:
            resultado["banos"] = 1
        elif "dos baños" in texto or "dos banos" in texto:
            resultado["banos"] = 2
        elif "tres baños" in texto or "tres banos" in texto:
            resultado["banos"] = 3

    # Ambientes autorizados
    ambientes_posibles = {
        "living": "Living",
        "comedor": "Comedor",
        "sala de estar": "Sala de estar",
        "sala": "Sala de estar",
        "estacionamiento": "Estacionamiento",
        "garaje": "Estacionamiento",
        "cochera": "Estacionamiento",
        "cocina": "Cocina",
        "lavandería": "Lavandería",
        "lavanderia": "Lavandería",
        "balcón": "Balcón/Terraza",
        "balcon": "Balcón/Terraza",
        "terraza": "Balcón/Terraza",
        "jardín": "Jardín",
        "jardin": "Jardín",
        "patio": "Jardín",
        "vestidor": "Vestidor",
        "closet": "Vestidor"
    }
    
    for palabra, nombre in ambientes_posibles.items():
        if palabra in texto:
            if nombre not in resultado["ambientes"]:
                resultado["ambientes"].append(nombre)
                
    # Adicionales
    adicionales_detectados = []
    if any(p in texto for p in ["piscina", "alberca", "pileta", "picnia"]):
        adicionales_detectados.append("Piscina")
    if any(p in texto for p in ["quincho", "parrillero", "churrasquero", "asador"]):
        adicionales_detectados.append("Quincho / Parrillero")
    if any(p in texto for p in ["domotica", "inteligente", "automatizado"]):
        adicionales_detectados.append("Domótica")
    if any(p in texto for p in ["sauna", "spa"]):
        adicionales_detectados.append("Sauna")
    if any(p in texto for p in ["gimnasio", "gym"]):
        adicionales_detectados.append("Gimnasio")
        
    resultado["adicionales"] = ", ".join(adicionales_detectados)
    
    return resultado


def extraer_datos_cotizacion(transcripcion: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    modelo = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()
    
    resultado = {
        "transcripcion": transcripcion,
        "ubicacion": "",
        "m2_terreno": 0,
        "m2_construir": 100,
        "habitaciones": 1,
        "banos": 1,
        "calidad_materiales": "Estándar",
        "ambientes": [],
        "adicionales": ""
    }
    
    if not api_key:
        print("Advertencia: GEMINI_API_KEY no configurada. Usando extractor heurístico por defecto.")
        return heuristica_extraer_datos(transcripcion, resultado)
        
    try:
        client = genai.Client(api_key=api_key)
        
        prompt = f"""
        Analiza la siguiente transcripción de un cliente que describe la obra de construcción que desea y extrae los siguientes datos estructurados en formato JSON.

        Campos JSON a devolver:
        - "ubicacion": Ciudad, zona o dirección física que mencione el usuario (ej. "Santa Cruz", "Caranavi"). Si no se menciona, dejar "".
        - "m2_terreno": Metros cuadrados del terreno como número entero (ej. 250). Si no se menciona, dejar 0.
        - "m2_construir": Metros cuadrados a construir como número entero. Si no se menciona pero se describen ambientes, estima un área aproximada (ej. 50m2 por habitación/comedor/cocina), sino pon 100 por defecto.
        - "habitaciones": Cantidad de habitaciones/dormitorios como número entero (por defecto 1).
        - "banos": Cantidad de baños como número entero (por defecto 1).
        - "calidad_materiales": Estrictamente una de estas opciones: "Estándar", "Premium", o "Lujo". Determínalo en base a palabras como "mármol", "fino", "lujoso", "sencillo", "económico".
        - "ambientes": Una lista de strings que representa los ambientes solicitados. Solo usa elementos de esta lista autorizada: ["Living", "Comedor", "Sala de estar", "Estacionamiento", "Cocina", "Lavandería", "Balcón/Terraza", "Jardín"].
        - "adicionales": Descripción de elementos adicionales o especiales requeridos (ej. "Piscina", "Quincho", "Parrilla", "Cuarto de herramientas").

        Transcripción:
        "{transcripcion}"

        Devuelve ÚNICAMENTE un objeto JSON válido con la estructura indicada. No agregues explicaciones ni delimitadores markdown, solo el objeto JSON directo.
        """
        
        response = client.models.generate_content(
            model=modelo,
            contents=prompt
        )
        
        texto_respuesta = (response.text or "").strip()
        
        match = re.search(r"\{.*\}", texto_respuesta, re.DOTALL)
        if match:
            texto_respuesta = match.group(0)
            
        datos_ia = json.loads(texto_respuesta)
        
        for key in resultado.keys():
            if key in datos_ia:
                resultado[key] = datos_ia[key]
                
        val_terreno = datos_ia.get("m2_terreno")
        if val_terreno is not None:
            resultado["m2_terreno"] = int(val_terreno)

        val_construir = datos_ia.get("m2_construir")
        if val_construir is not None:
            resultado["m2_construir"] = int(val_construir)

        val_habitaciones = datos_ia.get("habitaciones")
        if val_habitaciones is not None:
            resultado["habitaciones"] = int(val_habitaciones)

        val_banos = datos_ia.get("banos")
        if val_banos is not None:
            resultado["banos"] = int(val_banos)
        
        if resultado["calidad_materiales"] not in ["Estándar", "Premium", "Lujo"]:
            resultado["calidad_materiales"] = "Estándar"
            
        return resultado
        
    except Exception as e:
        print(f"Error llamando a Gemini para cotización: {e}. Usando extractor heurístico de respaldo.")
        return heuristica_extraer_datos(transcripcion, resultado)


@router.post("/cotizar-audio", response_model=CotizarAudioResponse)
async def cotizar_audio(audio: UploadFile = File(...)):
    ruta_temporal = None
    try:
        ruta_temporal = await guardar_audio_temporal(audio)
        transcripcion = transcribir_audio(str(ruta_temporal))
        
        if not transcripcion or transcripcion == "No se pudo transcribir el audio.":
            raise HTTPException(
                status_code=400,
                detail="No se pudo transcribir el audio."
            )
            
        datos_cotizacion = extraer_datos_cotizacion(transcripcion)
        return datos_cotizacion
        
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Error al cotizar audio con IA: {str(error)}"
        )
    finally:
        if ruta_temporal and ruta_temporal.exists():
            try:
                os.remove(ruta_temporal)
            except Exception:
                pass