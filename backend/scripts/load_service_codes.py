#!/usr/bin/env python3
"""
Load service codes into MongoDB from a JSON file.

Usage:
    cd backend
    source venv/bin/activate
    python scripts/load_service_codes.py [path/to/service_codes.json]

Default input file: scripts/service_codes.json (gitignored — do NOT commit real codes)
See:              scripts/service_codes.sample.json for expected format.

The script will:
  1. Drop all existing documents from the `service_codes` collection.
  2. Insert each code from the JSON array as a fresh, unused document.
"""

import asyncio
import json
import sys
import os
from pathlib import Path
from datetime import datetime

# Allow running from backend/ or project root
sys.path.insert(0, str(Path(__file__).parent.parent))

from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("MONGO_DB_NAME", "triptracks")


async def load_codes(json_path: str) -> None:
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DB_NAME]
    collection = db["service_codes"]

    # Load codes from JSON
    with open(json_path, "r") as f:
        codes: list[str] = json.load(f)

    if not isinstance(codes, list):
        print("ERROR: JSON must be an array of code strings.")
        sys.exit(1)

    # Validate format: 12-char alphanumeric uppercase
    invalid = [c for c in codes if not (isinstance(c, str) and len(c) == 12 and c.isalnum() and c == c.upper())]
    if invalid:
        print(f"ERROR: Invalid codes (must be 12-char A-Z/0-9 uppercase): {invalid}")
        sys.exit(1)

    # Clear existing codes
    result = await collection.delete_many({})
    print(f"Cleared {result.deleted_count} existing service codes.")

    # Insert new codes
    docs = [{"code": c, "is_used": False, "used_by": None, "used_at": None} for c in codes]
    insert_result = await collection.insert_many(docs)
    print(f"Inserted {len(insert_result.inserted_ids)} service codes.")

    client.close()


if __name__ == "__main__":
    json_file = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).parent / "service_codes.json")
    if not os.path.exists(json_file):
        print(f"ERROR: File not found: {json_file}")
        print("Create service_codes.json or copy from service_codes.sample.json")
        sys.exit(1)
    asyncio.run(load_codes(json_file))
