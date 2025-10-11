from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from .services import jwt_service
from .models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

credentials_exception = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)

async def get_user_from_token(token: str) -> User:
    """
    Decodes a JWT token, validates its data, and retrieves the corresponding user.
    Raises HTTPException on failure.
    """
    token_data = jwt_service.decode_access_token(token)
    if not token_data or not token_data.username:
        raise credentials_exception
    
    user = await User.find_one(User.username == token_data.username)
    if user is None:
        raise credentials_exception
    return user

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """
    FastAPI dependency to get the current user from an OAuth2 token.
    """
    return await get_user_from_token(token)
