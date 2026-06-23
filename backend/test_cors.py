import urllib.request

base_url = "http://127.0.0.1:8000/ia/preguntar-contexto"
headers = {
    "Origin": "http://localhost:4200",
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "content-type,x-empresa-id,x-usuario-id"
}

print("Sending OPTIONS preflight request...")
req = urllib.request.Request(
    base_url,
    headers=headers,
    method="OPTIONS"
)

try:
    with urllib.request.urlopen(req) as response:
        status = response.getcode()
        resp_headers = response.info()
        print(f"OPTIONS status: {status}")
        print("Response headers:")
        for k, v in resp_headers.items():
            print(f" - {k}: {v}")
except Exception as e:
    print(f"OPTIONS failed: {e}")
    if hasattr(e, "read"):
        print(e.read().decode("utf-8"))
