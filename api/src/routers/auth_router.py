from fastapi import APIRouter, HTTPException, Depends, Body
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta, datetime
from typing import Optional
from ..services import AuthService, jwt_service
from ..security import get_current_user_id
from ..schemas import (
    UserCreate,
    UserPublic,
    UserLogin,
    RefreshTokenRequest,
    SendOTPRequest,
    SendOTPResponse,
    VerifyOTPRequest,
    VerifyOTPResponse,
    ResetPasswordRequest,
    ResetPasswordResponse,
    ChangeEmailVerifyPasswordRequest,
    ChangeEmailVerifyPasswordResponse,
    UpdateEmailRequest,
    UpdateEmailResponse
)
from ..services.jwt_service import ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter(tags=["Auth"])

@router.post("/register", response_model=UserPublic, status_code=201)
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

@router.post("/login")
async def login_for_access_token(login_data: UserLogin):
    """
    Endpoint để đăng nhập và nhận token truy cập.
    - Sử dụng UserLogin schema để nhận email, mật khẩu và device_token.
    - Gọi AuthService để xác thực người dùng.
    - Nếu xác thực thành công, tạo token JWT.
    - Trả về token truy cập và loại token.
    - Ném lỗi HTTP 401 nếu thông tin đăng nhập không chính xác.
    """
    try:
        # Xác thực người dùng bằng username và mật khẩu
        user = await AuthService.login_user(
            username=login_data.username,
            password=login_data.password,
            device_token=login_data.device_token
        )
        if not user:
            # Nếu không tìm thấy người dùng hoặc mật khẩu sai, trả về lỗi 401
            raise HTTPException(
                status_code=401,
                detail="Tên đăng nhập hoặc mật khẩu không chính xác",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except ValueError as e:
        # Xử lý trường hợp tài khoản bị xóa
        raise HTTPException(
            status_code=403,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Tạo token truy cập với thời gian hết hạn
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = jwt_service.create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )

        # Tạo refresh token (phải dùng user.id giống access token)
    refresh_token = jwt_service.create_refresh_token(
        data={"sub": str(user.id)}
    )
    
    # Trả về cả hai token
    return {
        "access_token": access_token, 
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@router.post("/refresh")
async def refresh_access_token(payload: RefreshTokenRequest):
    """
    Nhận một refresh token và trả về một access token mới.
    """
    from bson import ObjectId
    from ..models import User
    
    # Decode refresh token (dùng hàm decode_access_token vì logic giống nhau)
    token_data = jwt_service.decode_access_token(payload.refresh_token)
    
    if not token_data or not token_data.username:
        raise HTTPException(
            status_code=401,
            detail="Refresh token không hợp lệ hoặc đã hết hạn",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Xác minh user vẫn tồn tại trong database
    try:
        user_id = ObjectId(token_data.username)  # token_data.username chứa user ID
        user = await User.find_one(User.id == user_id)
        if not user:
            raise HTTPException(
                status_code=401,
                detail="User không tồn tại",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Kiểm tra nếu tài khoản đã bị xóa
        if user.status == 'deleted':
            raise HTTPException(
                status_code=403,
                detail="Tài khoản đã bị xóa. Vui lòng liên hệ hỗ trợ nếu cần khôi phục.",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Refresh token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Tạo access token mới với user ID (không phải username)
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_access_token = jwt_service.create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    
    return {"access_token": new_access_token, "token_type": "bearer"}

@router.post("/send-otp", response_model=SendOTPResponse)
async def send_otp(request: SendOTPRequest):
    """
    Endpoint để gửi mã OTP qua email.
    - Nhận username hoặc email của người dùng
    - Nếu là username thì lấy email tương ứng từ database
    - Tạo mã OTP 6 chữ số và gửi đến email
    - OTP có hiệu lực trong 5 phút
    """
    try:
        result = await AuthService.send_otp(request.identifier)
        return SendOTPResponse(
            message=result["message"],
            email=result["email"]
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp(request: VerifyOTPRequest):
    """
    Endpoint để xác minh mã OTP.
    - Nhận email và mã OTP
    - Kiểm tra OTP có hợp lệ và chưa hết hạn
    - Đánh dấu OTP đã sử dụng sau khi xác minh thành công
    """
    try:
        result = await AuthService.verify_otp(request.email, request.otp_code)
        return VerifyOTPResponse(
            message=result["message"],
            email=result["email"]
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/reset-password", response_model=ResetPasswordResponse)
async def reset_password(request: ResetPasswordRequest):
    """
    Endpoint để đặt lại mật khẩu mới sau khi xác minh OTP.
    - Nhận email và mật khẩu mới
    - Kiểm tra email tồn tại và chưa bị xóa
    - Hash mật khẩu mới và cập nhật
    """
    try:
        result = await AuthService.reset_password(request.email, request.new_password)
        return ResetPasswordResponse(
            message=result["message"]
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/change-email/verify-password", response_model=ChangeEmailVerifyPasswordResponse)
async def change_email_verify_password(request: ChangeEmailVerifyPasswordRequest):
    """
    Endpoint để xác minh mật khẩu và gửi OTP đến email mới.
    - Nhận user_id, email mới và mật khẩu
    - Kiểm tra mật khẩu có đúng
    - Gửi OTP đến email mới
    """
    try:
        result = await AuthService.change_email_verify_password(
            request.user_id,
            request.new_email,
            request.password
        )
        return ChangeEmailVerifyPasswordResponse(
            message=result["message"],
            email=result["email"]
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/change-email/update", response_model=UpdateEmailResponse)
async def update_email(request: UpdateEmailRequest):
    """
    Endpoint để cập nhật email mới sau khi verify OTP.
    - Nhận user_id và email mới
    - Cập nhật email trong database
    """
    try:
        result = await AuthService.update_email(
            request.user_id,
            request.new_email
        )
        return UpdateEmailResponse(
            message=result["message"]
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/logout", status_code=200)
async def logout_user(
    request: dict = Body(...),
    user_id: str = Depends(get_current_user_id)
):
    """
    Endpoint để đăng xuất người dùng.
    - Xóa device token của thiết bị hiện tại khỏi danh sách deviceTokens của user
    - Chỉ xóa token được gửi đến (nếu có), không xóa tất cả tokens
    - Trả về 200 nếu thành công
    """
    try:
        from bson import ObjectId
        from ..models import User
        
        device_token = request.get("device_token")
        
        # Tìm user theo ID
        user = await User.find_one(User.id == ObjectId(user_id))
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Không tìm thấy người dùng"
            )
        
        # Nếu có device_token được gửi đến, xóa nó khỏi list
        if device_token and device_token.strip():
            # Đảm bảo deviceTokens là list
            if user.deviceTokens is None:
                user.deviceTokens = []
            
            # Log để debug
            print(f"📱 Logout: User {user_id}, Device token: {device_token[:20]}...")
            print(f"📱 Current deviceTokens count: {len(user.deviceTokens)}")
            
            # Xóa device token nếu có trong list
            if device_token in user.deviceTokens:
                original_count = len(user.deviceTokens)
                user.deviceTokens.remove(device_token)
                print(f"✅ Device token removed. Count: {original_count} -> {len(user.deviceTokens)}")
                
                # Save user với updatedAt
                user.updatedAt = datetime.utcnow() + timedelta(hours=7)
                
                # Sử dụng replace() thay vì save() để đảm bảo update được ghi vào database
                await user.replace()
                
                # Verify sau khi save
                updated_user = await User.find_one(User.id == ObjectId(user_id))
                if updated_user:
                    print(f"✅ User saved successfully. Verified count: {len(updated_user.deviceTokens)}")
                else:
                    print(f"⚠️ Could not verify user after save")
            else:
                print(f"⚠️ Device token not found in list.")
                print(f"   Searching for: {device_token[:20] if len(device_token) > 20 else device_token}...")
                print(f"   Available tokens ({len(user.deviceTokens)}): {[token[:20] + '...' if len(token) > 20 else token for token in (user.deviceTokens or [])]}")
        else:
            print(f"⚠️ No device_token provided in logout request")
        
        return {"message": "Đăng xuất thành công"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi khi đăng xuất: {str(e)}"
        )