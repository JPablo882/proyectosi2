from database import engine
from sqlalchemy import text

with engine.begin() as conn:
    try:
        conn.execute(text("ALTER TABLE empresa ADD COLUMN logo TEXT;"))
        print("Columna 'logo' agregada exitosamente a la tabla 'empresa'.")
    except Exception as e:
        print(f"Error o la columna ya existe: {e}")
