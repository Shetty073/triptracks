from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from app.models.user import UserCreate, UserDB, Token
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token
from app.core.database import db
import uuid

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

@router.post("/register", response_model=UserDB)
async def register(user: UserCreate):
    existing_user = await db.db["users"].find_one({"email": user.email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = get_password_hash(user.password)
    user_db = UserDB(
        id=str(uuid.uuid4()),
        email=user.email,
        username=user.username,
        hashed_password=hashed_password
    )
    
    await db.db["users"].insert_one(user_db.dict())
    return user_db

@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user_dict = await db.db["users"].find_one({"username": form_data.username}) # Using username for login here, could be email
    if not user_dict:
        # Fallback to email search if username not found
        user_dict = await db.db["users"].find_one({"email": form_data.username})
        if not user_dict:
            raise HTTPException(status_code=400, detail="Incorrect email/username or password")
            
    if not verify_password(form_data.password, user_dict["hashed_password"]):
        raise HTTPException(status_code=400, detail="Incorrect email/username or password")
        
    access_token = create_access_token(data={"sub": user_dict["id"]})
    refresh_token = create_refresh_token(data={"sub": user_dict["id"]})
    
    return {"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer"}

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
