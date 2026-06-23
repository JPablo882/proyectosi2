from typing import Optional
from datetime import date
from decimal import Decimal
from sqlmodel import SQLModel, Field


class Cotizacion(SQLModel, table=True):
    __tablename__ = "cotizacion"  # type: ignore

    id_cotizacion: Optional[int] = Field(default=None, primary_key=True)
    id_usuarios: Optional[int] = Field(default=None, foreign_key="usuario.id_usuarios")
    nombre: Optional[str] = Field(default=None)
    ubicacion: str
    m2_terreno: int = 0
    m2_construir: int = 100
    habitaciones: int = 1
    banos: int = 1
    calidad_materiales: str = "Estándar"
    ambientes: str  # Lista separada por comas, ej. "Living,Comedor,Cocina"
    adicionales: Optional[str] = None
    costo_estimado: Decimal
    fecha: Optional[date] = Field(default_factory=date.today)
    estado: str = "Pendiente"  # "Pendiente", "Aprobado", "Rechazado"
