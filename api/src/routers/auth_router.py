from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from ..services import AuthService, jwt_service
from ..schemas import UserCreate, UserPublic

router = APIRouter(tags=["Auth"])

ACCESS_TOKEN_EXPIRE_MINUTES = 30

@router.post("/api/auth/register", response_model=UserPublic, status_code=201)
def register_user(user_data: UserCreate):
    try:
        new_user = AuthService.register_user(
            username=user_data.username,
            email=user_data.email,
            password=user_data.password,
            displayName=user_data.displayName
        )
        # Một chút mẹo để khớp với lược đồ UserPublic, vốn mong đợi 'id'
        return UserPublic(
            id=str(new_user._id),
            username=new_user.username,
            email=new_user.email,
            displayName=new_user.displayName
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/api/auth/login")
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = AuthService.login_user(email=form_data.username, password=form_data.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = jwt_service.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}