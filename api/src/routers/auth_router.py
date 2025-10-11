from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from ..services import AuthService, jwt_service
from ..schemas import UserCreate, UserPublic
from ..services.jwt_service import ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter(tags=["Auth"])

@router.post("/api/auth/register", response_model=UserPublic, status_code=201)
async def register_user(user_data: UserCreate):
    """
    Endpoint để đăng ký người dùng mới.
    - Nhận dữ liệu người dùng (tên người dùng, email, mật khẩu, tên hiển thị).
    - Gọi AuthService để xử lý logic đăng ký.
    - Trả về thông tin người dùng công khai nếu thành công.
    - Ném lỗi HTTP 400 nếu tên người dùng hoặc email đã tồn tại.
    """
    try:
        # Gọi phương thức đăng ký người dùng bất đồng bộ từ service
        new_user = await AuthService.register_user(
            username=user_data.username,
            email=user_data.email,
            password=user_data.password,
            displayName=user_data.displayName
        )
        # Trả về thông tin người dùng công khai, chuyển đổi _id thành id
        return UserPublic(
            id=str(new_user.id),
            username=new_user.username,
            email=new_user.email,
            displayName=new_user.displayName
        )
    except ValueError as e:
        # Nếu có lỗi giá trị (ví dụ: người dùng đã tồn tại), trả về lỗi 400
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/api/auth/login")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Endpoint để đăng nhập và nhận token truy cập.
    - Sử dụng OAuth2PasswordRequestForm để nhận email (dưới dạng username) và mật khẩu.
    - Gọi AuthService để xác thực người dùng.
    - Nếu xác thực thành công, tạo token JWT.
    - Trả về token truy cập và loại token.
    - Ném lỗi HTTP 401 nếu thông tin đăng nhập không chính xác.
    """
    # Xác thực người dùng bằng email và mật khẩu
    user = await AuthService.login_user(email=form_data.username, password=form_data.password)
    if not user:
        # Nếu không tìm thấy người dùng hoặc mật khẩu sai, trả về lỗi 401
        raise HTTPException(
            status_code=401,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Tạo token truy cập với thời gian hết hạn
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = jwt_service.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    
    # Trả về token
    return {"access_token": access_token, "token_type": "bearer"}