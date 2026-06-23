from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    UploadFile,
    File,
    Form
)

from sqlmodel import Session, select

from models import DocumentoProyecto, AvanceProyecto, AvanceFoto
from database_empresa import get_session_empresa


router = APIRouter(
    prefix="/documentos",
    tags=["Documentos"]
)


@router.post("/subir")
async def subir_documento(

    archivo: UploadFile = File(...),

    nombre: str = Form(...),

    tipo: str = Form(...),

    formato: str = Form(...),

    tamano: str = Form(...),

    id_proyecto: int = Form(1),

    session: Session = Depends(get_session_empresa)

):

    carpeta = Path("uploads/documentos")

    carpeta.mkdir(
        parents=True,
        exist_ok=True
    )

    ruta_archivo = carpeta / archivo.filename

    contenido = await archivo.read()

    with open(ruta_archivo, "wb") as f:
        f.write(contenido)

    documento = DocumentoProyecto(

        id_proyecto=id_proyecto,

        nombre=nombre,

        tipo=tipo,

        archivo_url=str(ruta_archivo),

        tamano=tamano,

        formato=formato

    )

    session.add(documento)

    session.commit()

    session.refresh(documento)

    return documento


@router.post("/")
def crear_documento(
    documento: DocumentoProyecto,
    session: Session = Depends(get_session_empresa)
):

    session.add(documento)

    session.commit()

    session.refresh(documento)

    return documento


@router.get("/")
def listar_documentos(
    session: Session = Depends(get_session_empresa)
):

    return session.exec(
        select(DocumentoProyecto)
    ).all()


@router.delete("/{id_documento}")
def eliminar_documento(
    id_documento: int,
    session: Session = Depends(get_session_empresa)
):

    documento = session.get(
        DocumentoProyecto,
        id_documento
    )

    if documento:

        session.delete(documento)

        session.commit()

    return {"ok": True}


@router.post("/proyecto/{id_proyecto}/adjuntar")
async def adjuntar_archivo_proyecto(
    id_proyecto: int,
    archivo: UploadFile = File(...),
    tipo_adjunto: str = Form(...),  # 'foto', 'pdf', 'dwg'
    session: Session = Depends(get_session_empresa)
):
    # Determine directory
    if tipo_adjunto == "foto":
        carpeta = Path("uploads/avances")
    else:
        carpeta = Path("uploads/documentos")

    carpeta.mkdir(parents=True, exist_ok=True)
    
    # Save file content
    ruta_archivo = carpeta / archivo.filename
    contenido = await archivo.read()
    with open(ruta_archivo, "wb") as f:
        f.write(contenido)
        
    archivo_url = f"/uploads/{'avances' if tipo_adjunto == 'foto' else 'documentos'}/{archivo.filename}"

    if tipo_adjunto == "foto":
        # Check for client progress record
        avance = session.exec(
            select(AvanceProyecto)
            .where(AvanceProyecto.id_proyecto == id_proyecto)
            .where(AvanceProyecto.titulo == "Galería de Avances (Cliente)")
        ).first()
        
        if not avance:
            avance = AvanceProyecto(
                id_proyecto=id_proyecto,
                titulo="Galería de Avances (Cliente)",
                descripcion="Fotos de avance subidad por el cliente",
                porcentaje_avance=0,
                responsable="Cliente"
            )
            session.add(avance)
            session.commit()
            session.refresh(avance)
            
        foto = AvanceFoto(
            id_avance=avance.id_avance,
            ruta_foto=archivo_url
        )
        session.add(foto)
        session.commit()
        session.refresh(foto)

        # Notificar al cliente en tiempo real sobre la nueva foto
        try:
            from models import Proyecto
            from routers.notificaciones_app import enviar_notificacion_push
            proyecto = session.get(Proyecto, id_proyecto)
            if proyecto and proyecto.id_usuarios:
                enviar_notificacion_push(
                    id_usuario=proyecto.id_usuarios,
                    titulo=f"Nueva foto de avance: {proyecto.nombre}",
                    mensaje="Se ha subido una nueva imagen del avance de tu obra.",
                    data={"id_proyecto": str(id_proyecto), "tipo": "foto_avance"}
                )
        except Exception as e:
            print(f"Error al enviar notificación de foto subida: {e}")

        return {"mensaje": "Foto de avance subida correctamente", "foto": foto}
        
    else:
        tipo_doc = "Planos Arquitectónicos" if tipo_adjunto == "pdf" else "Boceto 3D y Renders"
        
        documento = DocumentoProyecto(
            id_proyecto=id_proyecto,
            nombre=archivo.filename,
            tipo=tipo_doc,
            archivo_url=archivo_url,
            tamano=f"{len(contenido) // 1024} KB",
            formato=tipo_adjunto
        )
        session.add(documento)
        session.commit()
        session.refresh(documento)
        return {"mensaje": "Documento subido correctamente", "documento": documento}