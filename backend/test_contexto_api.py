import urllib.request
import json

base_url = "http://127.0.0.1:8000/ia/preguntar-contexto"
headers = {
    "Content-Type": "application/json",
    "X-Empresa-Id": "1",
    "X-Usuario-Id": "1"
}

payload = {
    "pregunta": "¿de qué color es el cielo y qué es una constructora?"
}

print("Testing POST /ia/preguntar-contexto...")
req = urllib.request.Request(
    base_url,
    data=json.dumps(payload).encode("utf-8"),
    headers=headers,
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=15) as response:
        status = response.getcode()
        body = response.read().decode("utf-8")
        print(f"POST response status: {status}")
        result = json.loads(body)
        print("Response from Gemini Context:")
        print(result.get("respuesta"))
except Exception as e:
    print(f"POST failed: {e}")
    if hasattr(e, "read"):
        print(e.read().decode("utf-8"))
