from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import SQLModel, Session, select
from contextlib import asynccontextmanager

from database import engine
import models
from models import BaseDeDatosEmpresa
from database_empresa import construir_database_url_empresa, crear_tablas_empresa

from routers import incluir_routers


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Registrar tablas en la BD central
    SQLModel.metadata.create_all(engine)
    from sqlalchemy import text
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE cotizacion ADD COLUMN IF NOT EXISTS nombre VARCHAR(255);"))
            conn.execute(text("ALTER TABLE proyecto ADD COLUMN IF NOT EXISTS id_ingeniero INTEGER;"))
            conn.execute(text("ALTER TABLE proyecto ADD COLUMN IF NOT EXISTS id_residente INTEGER;"))
            conn.execute(text("ALTER TABLE proyecto ADD COLUMN IF NOT EXISTS id_maestro INTEGER;"))
            conn.execute(text("ALTER TABLE proyecto ADD COLUMN IF NOT EXISTS id_albaniles INTEGER[];"))
            conn.execute(text("ALTER TABLE proyecto ADD COLUMN IF NOT EXISTS id_ayudantes INTEGER[];"))
            conn.commit()
        except Exception as e:
            print(f"Error actualizando columnas en BD central: {e}")
            
    print("Tablas registradas central:")
    print(SQLModel.metadata.tables.keys())

    # Inicializar/Actualizar tablas en todas las BDs de empresas activas
    with Session(engine) as session_central:
        try:
            configs = session_central.exec(
                select(BaseDeDatosEmpresa).where(BaseDeDatosEmpresa.estado == True)
            ).all()
            for config in configs:
                try:
                    db_url = construir_database_url_empresa(config)
                    crear_tablas_empresa(db_url)
                    print(f"Tablas actualizadas para la empresa DB: {config.nombre_bd}")
                except Exception as e:
                    print(f"Error actualizando tablas para la empresa DB {config.nombre_bd}: {e}")
        except Exception as e:
            print(f"Error al obtener configuraciones de BD de empresas: {e}")
            
    yield


app = FastAPI(
    title="Backend FastAPI PostgreSQL Multiempresa",
    description="API modular para sistema multiempresa con FastAPI y PostgreSQL",
    version="1.0.0",
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi.staticfiles import StaticFiles
import os
os.makedirs("uploads", exist_ok=True)
os.makedirs("uploads/documentos", exist_ok=True)
os.makedirs("uploads/avances", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/", tags=["Inicio"])
def inicio():
    return {"mensaje": "Backend funcionando"}


@app.get("/health", tags=["Inicio"])
def health():
    return {"status": "ok"}


incluir_routers(app)

# Fuerza recarga de uvicorn tras cambios en crud/factory.py