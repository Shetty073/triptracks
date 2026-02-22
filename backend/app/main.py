from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.database import connect_to_mongo, close_mongo_connection
from app.api import auth, users, crew, trips
from app.websockets import chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    await connect_to_mongo()
    yield
    # Shutdown actions
    await close_mongo_connection()

app = FastAPI(title="Triptracks API", lifespan=lifespan)

# Add CORS Middleware to allow Flutter client requests (Web, Emulator, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, restrict this to specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(crew.router, prefix="/api/crew", tags=["crew"])
app.include_router(trips.router, prefix="/api/trips", tags=["trips"])
app.include_router(chat.router, prefix="/ws/trips", tags=["websockets"])

@app.get("/")
async def root():
    return {"message": "Welcome to Triptracks API"}
