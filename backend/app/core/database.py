from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorCollection
from app.core.config import settings
import certifi


# ─── Transparent wrapper that strips MongoDB _id from all read results ────────

class _CollectionWrapper:
    """Wraps a Motor collection to automatically exclude `_id` from all queries.
    This prevents the BSON ObjectId from leaking into Pydantic/FastAPI responses.
    """
    def __init__(self, collection: AsyncIOMotorCollection):
        self._col = collection
        self._NO_ID = {"_id": 0}

    async def find_one(self, filter=None, projection=None, **kwargs):
        proj = {**(projection or {}), **self._NO_ID}
        return await self._col.find_one(filter, proj, **kwargs)

    def find(self, filter=None, projection=None, *args, **kwargs):
        proj = {**(projection or {}), **self._NO_ID}
        return self._col.find(filter, proj, *args, **kwargs)

    async def insert_one(self, document, **kwargs):
        # Work on a copy so PyMongo's in-place _id mutation doesn't pollute callers
        return await self._col.insert_one(dict(document), **kwargs)

    async def insert_many(self, documents, **kwargs):
        return await self._col.insert_many([dict(d) for d in documents], **kwargs)

    async def update_one(self, filter, update, **kwargs):
        return await self._col.update_one(filter, update, **kwargs)

    async def update_many(self, filter, update, **kwargs):
        return await self._col.update_many(filter, update, **kwargs)

    async def delete_one(self, filter, **kwargs):
        return await self._col.delete_one(filter, **kwargs)

    async def delete_many(self, filter, **kwargs):
        return await self._col.delete_many(filter, **kwargs)

    async def count_documents(self, filter, **kwargs):
        return await self._col.count_documents(filter, **kwargs)


class _DatabaseWrapper:
    """Wraps a Motor database so every collection access returns a _CollectionWrapper."""
    def __init__(self):
        self._db = None

    def __setattr__(self, name, value):
        if name.startswith('_'):
            super().__setattr__(name, value)
        else:
            self.__dict__[name] = value

    def __getitem__(self, collection_name: str) -> _CollectionWrapper:
        return _CollectionWrapper(self._db[collection_name])

    @property
    def _delegate(self):
        return self._db


class Database:
    client: AsyncIOMotorClient = None
    db: _DatabaseWrapper = _DatabaseWrapper()


db = Database()


async def connect_to_mongo():
    db.client = AsyncIOMotorClient(
        settings.MONGODB_URL,
        tlsCAFile=certifi.where()
    )
    raw_db = db.client[settings.MONGODB_DB_NAME]
    db.db._db = raw_db
    print(f"Connected to MongoDB at {settings.MONGODB_URL}")


async def close_mongo_connection():
    if db.client:
        db.client.close()
        print("Closed MongoDB connection")
