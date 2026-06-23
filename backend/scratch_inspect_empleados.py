from sqlmodel import Session, select, create_engine
import os
from dotenv import load_dotenv

load_dotenv()

db_url = "postgresql://postgres:1234@127.0.0.1:5432/proysi2grup"
print("Connecting to tenant DB:", db_url)
engine = create_engine(db_url)

from models import Empleados

with Session(engine) as session:
    empleados = session.exec(select(Empleados)).all()
    print("Employees in proysi2grup:")
    for emp in empleados:
        print(f"ID: {emp.id_empleados}, Nombre: {repr(emp.nombre)}, Cargo: {repr(emp.cargo)}")
