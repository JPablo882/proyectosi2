import json
import asyncio
from typing import Dict, List, Optional
from fastapi import APIRouter
from fastapi.responses import StreamingResponse

router = APIRouter(
    prefix="/notificaciones",
    tags=["Notificaciones App"]
)

# Diccionario global para guardar las colas de notificaciones por usuario
# id_usuario -> list[asyncio.Queue]
active_connections: Dict[int, List[asyncio.Queue]] = {}

async def event_generator(id_usuario: int):
    queue = asyncio.Queue()
    if id_usuario not in active_connections:
        active_connections[id_usuario] = []
    active_connections[id_usuario].append(queue)
    
    try:
        # Enviar evento de conexión inicial
        yield f"data: {json.dumps({'type': 'connected', 'id_usuario': id_usuario})}\n\n"
        while True:
            try:
                # Esperamos un evento de la cola con timeout para enviar ping keepalive
                event = await asyncio.wait_for(queue.get(), timeout=20.0)
                yield f"data: {json.dumps(event)}\n\n"
            except asyncio.TimeoutError:
                # Comentario SSE para mantener viva la conexión
                yield ": ping\n\n"
    except asyncio.CancelledError:
        pass
    finally:
        # Limpieza al desconectarse el cliente
        if id_usuario in active_connections:
            if queue in active_connections[id_usuario]:
                active_connections[id_usuario].remove(queue)
            if not active_connections[id_usuario]:
                del active_connections[id_usuario]

@router.get("/stream/{id_usuario}")
async def stream_notificaciones(id_usuario: int):
    """
    Establece un canal SSE (Server-Sent Events) en tiempo real para el usuario indicado.
    """
    return StreamingResponse(
        event_generator(id_usuario),
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Content-Type": "text/event-stream",
            "X-Accel-Buffering": "no" # Prevenir que proxies como Nginx bufericen el stream
        },
        media_type="text/event-stream"
    )

def enviar_notificacion_push(id_usuario: int, titulo: str, mensaje: str, data: Optional[dict] = None):
    """
    Función global para enviar notificaciones en tiempo real al usuario de la app móvil.
    """
    event = {
        "type": "notification",
        "title": titulo,
        "body": mensaje,
        "data": data or {}
    }
    
    queues = active_connections.get(id_usuario, [])
    for q in queues:
        q.put_nowait(event)
        
    print(f"[SSE NOTIFICATION] Para usuario ID {id_usuario}: '{titulo}' - '{mensaje}' (Conexiones activas: {len(queues)})")
