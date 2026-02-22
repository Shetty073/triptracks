from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class ServiceCode(BaseModel):
    """A one-time-use service code that gates user registration."""
    code: str                          # 12-char alphanumeric (A-Z, 0-9)
    is_used: bool = False
    used_by: Optional[str] = None      # User ID
    used_at: Optional[datetime] = None
