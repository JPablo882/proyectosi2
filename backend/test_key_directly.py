import os
from pathlib import Path
from dotenv import load_dotenv
from google import genai

# Load env file directly
ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(ENV_PATH, override=True)

api_key = os.getenv("GEMINI_API_KEY", "").strip()
modelo = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()

print(f"Loaded API Key: {api_key}")
print(f"Key starts with AQ: {api_key.startswith('AQ.')}")

try:
    client = genai.Client(api_key=api_key)
    response = client.models.generate_content(
        model=modelo,
        contents="Hola, responde con la palabra 'FUNCIONANDO'"
    )
    print("Response text:")
    print(response.text)
except Exception as e:
    print(f"Direct call failed: {e}")
