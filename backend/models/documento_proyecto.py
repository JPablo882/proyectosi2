from datetime import date
from sqlmodel import SQLModel, Field

class DocumentoProyecto(SQLModel, table=True):

    __tablename__ = "documento_proyecto"  # type: ignore

    id_documento: int | None = Field(
        default=None,
        primary_key=True
    )

    id_proyecto: int = Field(
        foreign_key="proyecto.id_proyecto"
    )

    nombre: str

    tipo: str

    archivo_url: str

    tamano: str | None = None

    formato: str | None = None

    fecha_subida: date = Field(
        default_factory=date.today
    )