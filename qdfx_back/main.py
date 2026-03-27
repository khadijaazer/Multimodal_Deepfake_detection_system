from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

# 1. IMPORT BOTH ROUTERS HERE
from routers import scanner
from routers import auth # <--- YOU NEED THIS LINE
from scam_engine import load_model

app = FastAPI()

# EXACT CORS FROM YOUR FRIEND
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost", "http://localhost:8000", "http://127.0.0.1:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
    response.headers["Access-Control-Max-Age"] = "3600"
    return response

@app.options("/{full_path:path}")
async def options_handler(request: Request, full_path: str):
    return JSONResponse(content={}, headers={
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Accept",
        "Access-Control-Max-Age": "3600",
    })

# START THE AI WHEN SERVER STARTS
@app.on_event("startup")
async def startup_event():
    load_model()

# 2. CONNECT BOTH ROUTERS HERE
# This keeps the URLs EXACTLY as /analyze, /health, etc.
app.include_router(scanner.router)

# This adds your new email verification endpoint
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"]) # <--- YOU NEED THIS LINE


if __name__ == "__main__":
    from scam_engine import HF_MODEL_NAME
    print("=" * 60)
    print("Starting Enhanced Multilingual Scam Detection Server")
    print("=" * 60)
    print(f"Model source: {HF_MODEL_NAME}")
    print("Server will run at: http://localhost:8000")
    print("API endpoints:")
    print("  - POST /analyze  (enhanced analysis)")
    print("  - POST /api/auth/verify-corporate-email (email verification)") # Added to prints
    print("  - GET  /health    (check server status)")
    print("  - GET  /model-info (model information)")
    print("=" * 60)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)