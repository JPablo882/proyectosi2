from datetime import date
from sqlmodel import SQLModel, Field


class AvanceProyecto(SQLModel, table=True):

    __tablename__ = "avance_proyecto"  # type: ignore

    id_avance: int | None = Field(
        default=None,
        primary_key=True
    )

    id_proyecto: int = Field(
        foreign_key="proyecto.id_proyecto"
    )

    titulo: str

    descripcion: str | None = None

    porcentaje_avance: int

    responsable: str | None = None

    fecha_avance: date = Field(
        default_factory=date.today
    )