import os
from pathlib import Path
from dotenv import load_dotenv
from google import genai


ENV_PATH = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(ENV_PATH, override=True)


def responder_con_gemini(pregunta: str, historial: list = None) -> str:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    modelo = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()

    if not api_key:
        raise RuntimeError("Falta GEMINI_API_KEY en el archivo .env")

    if api_key.startswith("AQ."):
        raise ValueError("Las API Key con prefijo 'AQ.' indican que la cuenta de Google AI Studio tiene restricciones de seguridad, por lo que Google bloquea su uso en llamadas estándar del SDK. Debes crear una clave estándar ('AIzaSy...') usando una cuenta de Google diferente.")

    client = genai.Client(api_key=api_key)

    texto_historial = ""
    if historial:
        texto_historial = "\n--- HISTORIAL DE LA CONVERSACIÓN PREVIA ---\n"
        for msg in historial:
            emisor = "Usuario" if msg.get("rol") == "usuario" else "Asistente"
            texto_historial += f"{emisor}: {msg.get('mensaje', '')}\n"
        texto_historial += "-------------------------------------------\n"

    prompt = f"""
Eres un asistente inteligente para un sistema multiempresa orientado a construcción.

Tu función es ayudar al usuario con consultas técnicas, administrativas o generales relacionadas con construcción, empresas, materiales, costos, solicitudes, servicios y gestión.

Responde en español, de forma clara, útil y directa.
{texto_historial}
Pregunta actual del usuario:
{pregunta}
"""

    respuesta = client.models.generate_content(
        model=modelo,
        contents=prompt
    )

    return respuesta.text or "No se pudo generar una respuesta de IA."