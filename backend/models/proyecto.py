from typing import Optional, List
from datetime import date
from sqlmodel import SQLModel, Field
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import ARRAY, INTEGER


class Proyecto(SQLModel, table=True):
    __tablename__ = "proyecto"  # type: ignore

    id_proyecto: Optional[int] = Field(default=None, primary_key=True)
    id_usuarios: Optional[int] = Field(default=None, foreign_key="usuario.id_usuarios")
    nombre: str
    ubicacion: str
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    estado: str
    id_ingeniero: Optional[int] = Field(default=None, foreign_key="empleados.id_empleados")
    id_residente: Optional[int] = Field(default=None, foreign_key="empleados.id_empleados")
    id_maestro: Optional[int] = Field(default=None, foreign_key="empleados.id_empleados")
    id_albaniles: Optional[List[int]] = Field(default=[], sa_column=Column(ARRAY(INTEGER)))
    id_ayudantes: Optional[List[int]] = Field(default=[], sa_column=Column(ARRAY(INTEGER)))