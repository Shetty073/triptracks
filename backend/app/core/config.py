from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Triptracks"
    SECRET_KEY: str = "supersecretkey"  # Will be overridden by .env
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    MONGODB_URL: str = "mongodb://localhost:27017"
    MONGODB_DB_NAME: str = "triptracks"
    GEOMAPS_API_KEY: str = ""
    MEMCACHED_SERVER: str = "localhost:11211"

    class Config:
        env_file = ".env"

settings = Settings()
