import os
import difflib
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from sqlmodel import Session, select
from sqlalchemy import func, or_

from database import get_session
from database_empresa import (
    get_session_empresa,
    construir_database_url_empresa,
    obtener_engine_empresa,
)
from models import Empresa, BaseDeDatosEmpresa, Usuario, Rol, Cliente
from utils.seguridad_roles import requerir_roles
from utils.bitacora import registrar_bitacora
from utils.email import enviar_correo


router = APIRouter(
    prefix="/login",
    tags=["Login - Multiempresa"]
)


def sugerir_correo_similar(email_ingresado: str, correos_existentes: List[str]) -> Optional[str]:
    # Buscar similitudes ignorando mayúsculas/minúsculas y espacios
    similares = difflib.get_close_matches(email_ingresado, correos_existentes, n=1, cutoff=0.85)
    return similares[0] if similares else None


class LoginEmpresaRequest(BaseModel):
    email: str = Field(..., min_length=5)
    contrasena: str = Field(..., min_length=4)


class LoginEmpresaResponse(BaseModel):
    mensaje: str
    id_empresa: int
    nombre_empresa: str
    email: str
    id_usuario_admin: int


class LoginUsuarioRequest(BaseModel):
    identificador: str = Field(..., min_length=3)
    contrasena: str = Field(..., min_length=4)


class LoginUsuarioResponse(BaseModel):
    mensaje: str
    id_empresa: int
    id_usuario: int
    usuario: str
    nombres: str
    apellido: str
    email: str
    rol: str


def registrar_login_empresa_en_bitacora(
    session_central: Session,
    id_empresa: int,
    descripcion: str,
):
    """
    Registra el login de empresa dentro de la BD propia de esa empresa.
    Usa id_usuario=1 porque al crear la empresa SaaS se crea un admin inicial.
    """

    config_bd = session_central.exec(
        select(BaseDeDatosEmpresa).where(
            BaseDeDatosEmpresa.id_empresa == id_empresa,
            BaseDeDatosEmpresa.estado == True,
        )
    ).first()

    if not config_bd:
        return

    try:
        database_url = construir_database_url_empresa(config_bd)
        engine_empresa = obtener_engine_empresa(database_url)

        with Session(engine_empresa) as session_empresa:
            usuario_admin = session_empresa.get(Usuario, 1)

            if usuario_admin:
                registrar_bitacora(
                    session=session_empresa,
                    id_usuario=1,
                    modulo="Login Empresa",
                    accion="Inicio de sesión",
                    descripcion=descripcion,
                )

    except Exception:
        pass


#iniciar sesión empresa
@router.post("/empresa", response_model=LoginEmpresaResponse)
def login_empresa(
    datos: LoginEmpresaRequest,
    session: Session = Depends(get_session),
):
    email_normalizado = datos.email.strip().lower()

    empresa = session.exec(
        select(Empresa).where(
            func.lower(Empresa.email) == email_normalizado
        )
    ).first()

    if not empresa:
        correos_db = session.exec(select(Empresa.email)).all()
        sugerencia = sugerir_correo_similar(email_normalizado, [e.lower() for e in correos_db if e])
        mensaje = "Credenciales de empresa incorrectas."
        if sugerencia:
            mensaje += f" ¿Quisiste decir '{sugerencia}'?"
        raise HTTPException(
            status_code=401,
            detail=mensaje
        )

    if empresa.contrasena != datos.contrasena:
        raise HTTPException(
            status_code=401,
            detail="Credenciales de empresa incorrectas."
        )

    if not empresa.estado:
        raise HTTPException(
            status_code=403,
            detail="La empresa no se encuentra activa."
        )

    id_empresa_valido = empresa.id_empresa
    if id_empresa_valido is None:
        raise HTTPException(
            status_code=500,
            detail="Error de consistencia: La empresa no tiene un ID asignado."
        )

    registrar_login_empresa_en_bitacora(
        session_central=session,
        id_empresa=id_empresa_valido,
        descripcion=f"La empresa {empresa.nombre} inició sesión correctamente.",
    )

    return {
        "mensaje": "Login de empresa correcto.",
        "id_empresa": id_empresa_valido,
        "nombre_empresa": empresa.nombre,
        "email": empresa.email,
        "id_usuario_admin": 1,
    }


#iniciar sesión usuario
@router.post("/usuario", response_model=LoginUsuarioResponse)
def login_usuario(
    datos: LoginUsuarioRequest,
    x_empresa_id: int = Header(..., alias="X-Empresa-Id"),
    session: Session = Depends(get_session_empresa),
):
    identificador = datos.identificador.strip().lower()

    usuario = session.exec(
        select(Usuario).where(
            or_(
                func.lower(Usuario.email) == identificador,
                func.lower(Usuario.nombresusuario) == identificador,
            )
        )
    ).first()

    if not usuario:
        correos_db = session.exec(select(Usuario.email)).all()
        sugerencia = sugerir_correo_similar(identificador, [e.lower() for e in correos_db if e])
        mensaje = "Credenciales de usuario incorrectas."
        if sugerencia:
            mensaje += f" ¿Quisiste decir '{sugerencia}'?"
        raise HTTPException(
            status_code=401,
            detail=mensaje
        )

    if usuario.contrasena != datos.contrasena:
        raise HTTPException(
            status_code=401,
            detail="Credenciales de usuario incorrectas."
        )

    rol = session.get(Rol, usuario.id_rol)

    if not rol:
        raise HTTPException(
            status_code=403,
            detail="El usuario no tiene rol asignado."
        )

    id_usuario_valido = usuario.id_usuarios
    if id_usuario_valido is None:
        raise HTTPException(
            status_code=500,
            detail="Error interno: El usuario no tiene un ID asignado."
        )

    registrar_bitacora(
        session=session,
        id_usuario=id_usuario_valido,
        modulo="Login Usuario",
        accion="Inicio de sesión",
        descripcion=f"El usuario {usuario.nombresusuario} inició sesión correctamente.",
    )

    return {
        "mensaje": "Login de usuario correcto.",
        "id_empresa": x_empresa_id,
        "id_usuario": id_usuario_valido,
        "usuario": usuario.nombresusuario,
        "nombres": usuario.nombres,
        "apellido": usuario.apellido,
        "email": usuario.email,
        "rol": rol.rol,
    }
    
class CerrarSesionResponse(BaseModel):
    mensaje: str
    id_empresa: int
    id_usuario: int
    usuario: str
    
@router.post("/cerrar-sesion", response_model=CerrarSesionResponse)
def cerrar_sesion(
    x_empresa_id: int = Header(..., alias="X-Empresa-Id"),
    session: Session = Depends(get_session_empresa),
    usuario_actual=Depends(requerir_roles("Administrador", "Empleado", "Cliente")),
):
    """
    Cierra la sesión del usuario dentro de una empresa activa.

    Multiempresa:
    - X-Empresa-Id define la base de datos de la empresa.
    - X-Usuario-Id identifica al usuario que cierra sesión.
    """

    usuario = usuario_actual["usuario"]

    id_usuario_valido = usuario.id_usuarios
    if id_usuario_valido is None:
        raise HTTPException(
            status_code=500,
            detail="Error interno: El usuario no tiene un ID asignado."
        )

    registrar_bitacora(
        session=session,
        id_usuario=id_usuario_valido,
        modulo="Login Usuario",
        accion="Cierre de sesión",
        descripcion=f"El usuario {usuario.nombresusuario} cerró sesión correctamente.",
    )

    return {
        "mensaje": "Sesión cerrada correctamente. El cliente debe eliminar los datos de sesión almacenados.",
        "id_empresa": x_empresa_id,
        "id_usuario": id_usuario_valido,
        "usuario": usuario.nombresusuario,
    }


# ============================================================
# ENDPOINTS GLOBALES - REGISTRO Y LOGIN GLOBAL MULTIEMPRESA
# ============================================================

class RegistroGlobalRequest(BaseModel):
    nombres: str = Field(..., min_length=1)
    apellido: str = Field(..., min_length=1)
    email: str = Field(..., min_length=5)
    contrasena: str = Field(..., min_length=4)
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class RegistroGlobalResponse(BaseModel):
    mensaje: str
    email: str

class LoginGlobalRequest(BaseModel):
    email: str = Field(..., min_length=5)
    contrasena: str = Field(..., min_length=4)

class EmpresaItem(BaseModel):
    id_empresa: int
    nombre: str
    email: str
    logo: Optional[str] = None

class LoginGlobalResponse(BaseModel):
    mensaje: str
    email: str
    nombres: str
    apellido: str
    empresas: List[EmpresaItem]

class SeleccionarEmpresaRequest(BaseModel):
    email: str
    id_empresa: int


# Registrar usuario globalmente
@router.post("/registro-global", response_model=RegistroGlobalResponse)
def registro_global(
    datos: RegistroGlobalRequest,
    session_central: Session = Depends(get_session),
):
    email_normalizado = datos.email.strip().lower()

    # Verificar si ya existe en la central
    usuario_existente = session_central.exec(
        select(Usuario).where(func.lower(Usuario.email) == email_normalizado)
    ).first()

    if usuario_existente:
        raise HTTPException(
            status_code=400,
            detail="El correo electrónico ya está registrado."
        )

    # Crear el usuario en la BD central
    nuevo_usuario = Usuario(
        id_rol=2,  # Cliente por defecto
        nombresusuario=email_normalizado.split('@')[0],
        nombres=datos.nombres,
        apellido=datos.apellido,
        email=email_normalizado,
        contrasena=datos.contrasena,
        telefono=datos.telefono,
        direccion=datos.direccion,
    )

    try:
        session_central.add(nuevo_usuario)
        session_central.commit()
        session_central.refresh(nuevo_usuario)
    except Exception as e:
        session_central.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error al registrar usuario: {str(e)}"
        )

    return {
        "mensaje": "Usuario global registrado correctamente.",
        "email": nuevo_usuario.email
    }


# Iniciar sesión global
@router.post("/login-global", response_model=LoginGlobalResponse)
def login_global(
    datos: LoginGlobalRequest,
    session_central: Session = Depends(get_session),
):
    email_normalizado = datos.email.strip().lower()

    usuario = session_central.exec(
        select(Usuario).where(func.lower(Usuario.email) == email_normalizado)
    ).first()

    if not usuario:
        correos_db = session_central.exec(select(Usuario.email)).all()
        sugerencia = sugerir_correo_similar(email_normalizado, [e.lower() for e in correos_db if e])
        mensaje = "Credenciales incorrectas."
        if sugerencia:
            mensaje += f" ¿Quisiste decir '{sugerencia}'?"
        raise HTTPException(
            status_code=401,
            detail=mensaje
        )

    if usuario.contrasena != datos.contrasena:
        raise HTTPException(
            status_code=401,
            detail="Credenciales incorrectas."
        )

    # Obtener todas las empresas activas
    empresas = session_central.exec(
        select(Empresa).where(Empresa.estado == "Activo")
    ).all()

    lista_empresas = [
        {
            "id_empresa": emp.id_empresa,
            "nombre": emp.nombre,
            "email": emp.email,
            "logo": getattr(emp, "logo", None)
        }
        for emp in empresas
    ]

    return {
        "mensaje": "Login global correcto.",
        "email": usuario.email,
        "nombres": usuario.nombres,
        "apellido": usuario.apellido,
        "empresas": lista_empresas
    }


# Vincular usuario a la empresa seleccionada y loguearlo
@router.post("/seleccionar-empresa", response_model=LoginUsuarioResponse)
def seleccionar_empresa(
    datos: SeleccionarEmpresaRequest,
    session_central: Session = Depends(get_session),
):
    # Buscar configuración de base de datos de la empresa elegida
    config_bd = session_central.exec(
        select(BaseDeDatosEmpresa).where(
            BaseDeDatosEmpresa.id_empresa == datos.id_empresa,
            BaseDeDatosEmpresa.estado == True,
        )
    ).first()

    if not config_bd:
        raise HTTPException(
            status_code=404,
            detail="No se encontró una base de datos activa para la empresa seleccionada."
        )

    # Buscar datos del usuario global
    usuario_central = session_central.exec(
        select(Usuario).where(func.lower(Usuario.email) == datos.email.strip().lower())
    ).first()

    if not usuario_central:
        raise HTTPException(
            status_code=404,
            detail="Usuario global no encontrado."
        )

    database_url = construir_database_url_empresa(config_bd)
    engine_empresa = obtener_engine_empresa(database_url)

    with Session(engine_empresa) as session_empresa:
        # Asegurar que el rol Cliente (ID 2) existe en la base de datos de la empresa
        rol_cliente = session_empresa.get(Rol, 2)
        if not rol_cliente:
            rol_cliente = Rol(
                id_rol=2,
                rol="Cliente",
                descripcion="Usuario cliente del sistema",
                niveljerarquia=2,
                fechacreacion=datetime.utcnow(),
            )
            try:
                session_empresa.add(rol_cliente)
                session_empresa.commit()
            except Exception:
                session_empresa.rollback()

        # Verificar si el usuario ya existe localmente
        usuario_local = session_empresa.exec(
            select(Usuario).where(func.lower(Usuario.email) == usuario_central.email.lower())
        ).first()

        if not usuario_local:
            usuario_local = Usuario(
                id_rol=2,  # Cliente
                nombresusuario=usuario_central.nombresusuario,
                nombres=usuario_central.nombres,
                apellido=usuario_central.apellido,
                email=usuario_central.email,
                contrasena=usuario_central.contrasena,
                telefono=usuario_central.telefono,
                direccion=usuario_central.direccion,
            )
            try:
                session_empresa.add(usuario_local)
                session_empresa.commit()
                session_empresa.refresh(usuario_local)
            except Exception as e:
                session_empresa.rollback()
                raise HTTPException(
                    status_code=500,
                    detail=f"No se pudo crear el usuario en la base de datos de la empresa: {str(e)}"
                )

        # Asegurar tipos y fallbacks para evitar alertas del tipado estático
        telefono_usuario: str = usuario_central.telefono or "SIN_FONO"
        telefono_cliente: str = usuario_central.telefono or ""
        direccion_cliente: str = usuario_central.direccion or ""

        # Verificar si el cliente ya existe en la tabla de clientes de la empresa
        nombre_completo = f"{usuario_central.nombres} {usuario_central.apellido}".strip()
        cliente_local = session_empresa.exec(
            select(Cliente).where(
                or_(
                    func.lower(Cliente.nombre) == nombre_completo.lower(),
                    func.lower(Cliente.telefono) == telefono_usuario.lower()
                )
            )
        ).first()

        if not cliente_local:
            cliente_local = Cliente(
                nombre=nombre_completo,
                telefono=telefono_cliente,
                direccion=direccion_cliente,
            )
            try:
                session_empresa.add(cliente_local)
                session_empresa.commit()
            except Exception as e:
                session_empresa.rollback()
                print(f"Advertencia: No se pudo agregar a la tabla cliente: {e}")

        # Retornar los mismos datos que el login de usuario regular
        rol = session_empresa.get(Rol, usuario_local.id_rol)
        rol_name = rol.rol if rol else "Cliente"

        id_usuario_valido = usuario_local.id_usuarios
        if id_usuario_valido is None:
            raise HTTPException(
                status_code=500,
                detail="Error interno: El usuario local no tiene un ID asignado."
            )

        return {
            "mensaje": "Login de usuario correcto.",
            "id_empresa": datos.id_empresa,
            "id_usuario": id_usuario_valido,
            "usuario": usuario_local.nombresusuario,
            "nombres": usuario_local.nombres,
            "apellido": usuario_local.apellido,
            "email": usuario_local.email,
            "rol": rol_name,
        }


# Cambiar contraseña global y localmente
class CambiarContrasenaRequest(BaseModel):
    email: str
    contrasena_actual: str
    nueva_contrasena: str

class CambiarContrasenaResponse(BaseModel):
    mensaje: str


@router.post("/cambiar-contrasena", response_model=CambiarContrasenaResponse)
def cambiar_contrasena(
    datos: CambiarContrasenaRequest,
    x_empresa_id: Optional[int] = Header(None, alias="X-Empresa-Id"),
    session_central: Session = Depends(get_session),
):
    email_normalizado = datos.email.strip().lower()

    # 1. Buscar el usuario globalmente
    usuario_central = session_central.exec(
        select(Usuario).where(func.lower(Usuario.email) == email_normalizado)
    ).first()

    if not usuario_central:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado."
        )

    # 2. Verificar contraseña actual
    if usuario_central.contrasena != datos.contrasena_actual:
        raise HTTPException(
            status_code=401,
            detail="La contraseña actual es incorrecta."
        )

    # 3. Actualizar la contraseña en la base central
    usuario_central.contrasena = datos.nueva_contrasena
    try:
        session_central.add(usuario_central)
        session_central.commit()
        session_central.refresh(usuario_central)
    except Exception as e:
        session_central.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error al actualizar la contraseña global: {str(e)}"
        )

    # 4. Si hay una empresa seleccionada, actualizar la contraseña en el tenant local también
    if x_empresa_id:
        config_bd = session_central.exec(
            select(BaseDeDatosEmpresa).where(
                BaseDeDatosEmpresa.id_empresa == x_empresa_id,
                BaseDeDatosEmpresa.estado == True,
            )
        ).first()

        if config_bd:
            database_url = construir_database_url_empresa(config_bd)
            engine_empresa = obtener_engine_empresa(database_url)
            with Session(engine_empresa) as session_empresa:
                usuario_local = session_empresa.exec(
                    select(Usuario).where(func.lower(Usuario.email) == email_normalizado)
                ).first()

                if usuario_local:
                    usuario_local.contrasena = datos.nueva_contrasena
                    try:
                        session_empresa.add(usuario_local)
                        session_empresa.commit()
                    except Exception as e:
                        session_empresa.rollback()
                        print(f"Advertencia: No se pudo actualizar contraseña en BD local: {e}")

    # 5. Enviar el correo de confirmación de éxito
    asunto = "Cambio de contraseña exitoso"
    contenido = f"""
Hola {usuario_central.nombres},

Te informamos que tu contraseña ha sido cambiada de manera exitosa en el sistema.

A partir de ahora, debes usar tu nueva contraseña para iniciar sesión en la aplicación móvil.

Si no realizaste este cambio, por favor ponte en contacto con soporte técnico de inmediato.

Atentamente,
Sistema Multiempresa
"""

    debug_skip_email = os.getenv("DEBUG_SKIP_EMAIL", "false").lower() == "true"
    if not debug_skip_email:
        try:
            enviar_correo(
                destinatario=usuario_central.email,
                asunto=asunto,
                contenido=contenido,
            )
        except Exception as error:
            print(f"Error al enviar correo de cambio de contraseña: {error}")

    return {
        "mensaje": "Contraseña cambiada correctamente. Se ha enviado un correo electrónico de confirmación."
    }