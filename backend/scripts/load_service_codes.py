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

import json
import sys
import os
from pathlib import Path

# Allow running from backend/ directory
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv

env_path = Path(__file__).parent.parent / ".env"
load_dotenv(env_path, override=True)

# Use the same env var names as app/core/config.py
MONGO_URI = os.getenv("MONGODB_URL")
if not MONGO_URI:
    print(f"ERROR: MONGODB_URL not found in {env_path}")
    sys.exit(1)
DB_NAME = os.getenv("MONGODB_DB_NAME", "triptracksdb")
print(f"Connecting to: {MONGO_URI[:40]}... / DB: {DB_NAME}")


def load_codes(json_path: str) -> None:
    import certifi
    from pymongo import MongoClient

    # Load codes from JSON
    with open(json_path, "r") as f:
        codes: list = json.load(f)

    if not isinstance(codes, list):
        print("ERROR: JSON must be an array of code strings.")
        sys.exit(1)

    # Validate format: 12-char alphanumeric uppercase
    invalid = [
        c for c in codes
        if not (isinstance(c, str) and len(c) == 12 and c.isalnum() and c == c.upper())
    ]
    if invalid:
        print(f"ERROR: Invalid codes (must be 12-char A-Z/0-9 uppercase): {invalid}")
        sys.exit(1)

    client = MongoClient(MONGO_URI, tlsCAFile=certifi.where())
    db = client[DB_NAME]
    collection = db["service_codes"]

    # Clear existing codes
    result = collection.delete_many({})
    print(f"Cleared {result.deleted_count} existing service codes.")

    # Insert new codes
    docs = [{"code": c, "is_used": False, "used_by": None, "used_at": None} for c in codes]
    insert_result = collection.insert_many(docs)
    print(f"Inserted {len(insert_result.inserted_ids)} service codes successfully.")

    client.close()


if __name__ == "__main__":
    json_file = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).parent / "service_codes.json")
    if not os.path.exists(json_file):
        print(f"ERROR: File not found: {json_file}")
        print("Create scripts/service_codes.json or copy from scripts/service_codes.sample.json")
        sys.exit(1)
    load_codes(json_file)
