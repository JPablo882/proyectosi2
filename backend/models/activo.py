from typing import Optional
from datetime import date
from decimal import Decimal
from sqlmodel import SQLModel, Field


class ActivosFijos(SQLModel, table=True):
    __tablename__ = "activos_fijos"  # type: ignore

    id_activo: Optional[int] = Field(default=None, primary_key=True)
    id_proyecto: Optional[int] = Field(default=None, foreign_key="proyecto.id_proyecto")
    nombre: str
    tipo_activo: str
    codigo_activo: str
    fechacompra: Optional[date] = None
    valor_compra: Decimal
    vida_util: int
    valor_residual: Decimal
    estado: str


class MantenimientoActivo(SQLModel, table=True):
    __tablename__ = "mantenimiento_activo"  # type: ignore

    id_mantenimiento: Optional[int] = Field(default=None, primary_key=True)
    id_activo: int = Field(foreign_key="activos_fijos.id_activo")
    fecha: date
    tipo: str  # Preventivo, Correctivo
    descripcion: str
    costo: Decimal
    estado: str  # Programado, Completado


class ActivoHistorico(SQLModel, table=True):
    __tablename__ = "activo_historico"  # type: ignore

    id_historico: Optional[int] = Field(default=None, primary_key=True)
    id_activo: int = Field(foreign_key="activos_fijos.id_activo")
    fecha: date
    accion: str  # Adquisición, Asignación, Devolución, Mantenimiento
    detalles: str