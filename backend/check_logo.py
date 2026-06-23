from database import engine
from sqlalchemy import text

conn = engine.connect()
result = conn.execute(text("SELECT id_empresa, length(logo) FROM empresa;"))
for row in result:
    print(f"Empresa: {row[0]}, Logo Length: {row[1]}")
conn.close()
