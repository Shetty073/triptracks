from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

class Database:
    client: AsyncIOMotorClient = None
    db = None

db = Database()

import certifi

async def connect_to_mongo():
    db.client = AsyncIOMotorClient(
        settings.MONGODB_URL,
        tlsCAFile=certifi.where()
    )
    db.db = db.client[settings.MONGODB_DB_NAME]
    print(f"Connected to MongoDB at {settings.MONGODB_URL}")

async def close_mongo_connection():
    if db.client:
        db.client.close()
        print("Closed MongoDB connection")
