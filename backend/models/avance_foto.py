from sqlmodel import SQLModel, Field


class AvanceFoto(SQLModel, table=True):

    __tablename__ = "avance_foto"  # type: ignore

    id_foto: int | None = Field(
        default=None,
        primary_key=True
    )

    id_avance: int = Field(
        foreign_key="avance_proyecto.id_avance"
    )

    ruta_foto: str