from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from app.models.user import UserCreate, UserDB, Token
from app.models.service_code import ServiceCode
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token
from app.core.database import db
from app.services.cache import cache_service
import uuid
from datetime import datetime, timezone

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

MOCK_OTP = "123456"
OTP_TTL = 600       # 10 minutes
OTP_VERIFIED_TTL = 900  # 15 minutes to complete registration after verification


# ─── Request/Response schemas ─────────────────────────────────────────────────

class OtpSendRequest(BaseModel):
    email: EmailStr

class OtpVerifyRequest(BaseModel):
    email: EmailStr
    otp: str

class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str
    full_name: str | None = None
    service_code: str


# ─── OTP Endpoints ────────────────────────────────────────────────────────────

@router.post("/otp/send")
async def send_otp(req: OtpSendRequest):
    """
    Send an OTP to the given email.
    Currently mocked — the OTP is always 123456.
    """
    cache_service.set(f"otp_{req.email}", MOCK_OTP, ttl=OTP_TTL)
    # TODO: replace with real email sending (e.g. SendGrid / SMTP)
    return {"message": "OTP sent to your email address."}


@router.post("/otp/verify")
async def verify_otp(req: OtpVerifyRequest):
    """Verify the OTP for an email. Marks email as verified in cache."""
    stored = cache_service.get(f"otp_{req.email}")
    if stored is None:
        raise HTTPException(status_code=400, detail="OTP expired or not requested. Please request a new OTP.")
    if stored != req.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP.")
    # Mark email as OTP-verified so the register endpoint can proceed
    cache_service.set(f"otp_verified_{req.email}", True, ttl=OTP_VERIFIED_TTL)
    cache_service.delete(f"otp_{req.email}")  # consume the OTP
    return {"verified": True}


# ─── Register ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=UserDB)
async def register(req: RegisterRequest):
    # 1. Check email OTP was verified
    if not cache_service.get(f"otp_verified_{req.email}"):
        raise HTTPException(
            status_code=400,
            detail="Email not verified. Please verify via OTP before registering."
        )

    # 2. Check email uniqueness
    if await db.db["users"].find_one({"email": req.email}):
        raise HTTPException(status_code=400, detail="Email already registered.")

    # 3. Check username uniqueness
    if await db.db["users"].find_one({"username": req.username}):
        raise HTTPException(status_code=400, detail="Username already taken.")

    # 4. Validate service code
    code_doc = await db.db["service_codes"].find_one({"code": req.service_code, "is_used": False})
    if not code_doc:
        raise HTTPException(status_code=400, detail="Invalid or already used service code.")

    # 5. Create user
    hashed_password = get_password_hash(req.password)
    user_id = str(uuid.uuid4())
    user_db = UserDB(
        id=user_id,
        email=req.email,
        username=req.username,
        full_name=req.full_name,
        hashed_password=hashed_password,
    )
    await db.db["users"].insert_one(user_db.dict())

    # 6. Mark service code as used
    await db.db["service_codes"].update_one(
        {"code": req.service_code},
        {"$set": {"is_used": True, "used_by": user_id, "used_at": datetime.now(timezone.utc)}}
    )

    # 7. Consume OTP verification
    cache_service.delete(f"otp_verified_{req.email}")

    return user_db


# ─── Login ────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    # Try username first, then email
    user_dict = await db.db["users"].find_one({"username": form_data.username})
    if not user_dict:
        user_dict = await db.db["users"].find_one({"email": form_data.username})
    if not user_dict:
        raise HTTPException(status_code=400, detail="Incorrect email/username or password.")

    if not verify_password(form_data.password, user_dict["hashed_password"]):
        raise HTTPException(status_code=400, detail="Incorrect email/username or password.")

    access_token = create_access_token(data={"sub": user_dict["id"]})
    refresh_token = create_refresh_token(data={"sub": user_dict["id"]})
    return {"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer"}


# ─── Auth Dependency ──────────────────────────────────────────────────────────

async def get_current_user(token: str = Depends(oauth2_scheme)):
    from jose import jwt, JWTError
    from app.core.config import settings
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = await db.db["users"].find_one({"id": user_id})
    if user is None:
        raise credentials_exception
    return UserDB(**user)
