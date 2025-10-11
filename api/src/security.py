from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from .services import jwt_service
from .models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token_data = jwt_service.decode_access_token(token)
    if token_data is None:
        raise credentials_exception
    user = User.find_by_username(token_data.username)
    if user is None:
        raise credentials_exception
    return user
