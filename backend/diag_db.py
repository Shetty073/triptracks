import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv

load_dotenv()

async def main():
    uri = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    db_name = os.getenv("DATABASE_NAME", "triptracks")
    client = AsyncIOMotorClient(uri)
    db = client[db_name]
    
    # 1. List all users
    print("User List:")
    cursor = db["users"].find({})
    users = await cursor.to_list(length=100)
    for u in users:
        v_count = len(u.get("profile_settings", {}).get("vehicles", []))
        print(f"- {u.get('username')} (id: {u.get('id')}) Email: {u.get('email')} Vehicles: {v_count}")
        if v_count > 0:
            for v in u['profile_settings']['vehicles']:
                print(f"  * {v.get('name')} (id: {v.get('id')})")

    # 2. Simulate the query in crew.py
    # Let's assume testuser is the current user.
    testuser = await db["users"].find_one({"username": "testuser"})
    if testuser:
        me_id = testuser['id']
        crew_ids = testuser.get('crew_ids', [])
        member_ids = list(set(crew_ids + [me_id]))
        print(f"\nSimulating crew query for 'testuser' (id: {me_id})")
        print(f"Member IDs: {member_ids}")
        
        cursor = db["users"].find({"id": {"$in": member_ids}})
        crew = await cursor.to_list(length=100)
        print(f"Query returned {len(crew)} members.")
        for c in crew:
            print(f" - {c.get('username')} (id: {c.get('id')})")

if __name__ == "__main__":
    asyncio.run(main())
