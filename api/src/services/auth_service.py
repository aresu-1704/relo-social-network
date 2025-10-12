from passlib.context import CryptContext
from ..models.user import User

# Thiết lập ngữ cảnh băm mật khẩu
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class AuthService:

    @staticmethod
    def verify_password(plain_password, hashed_password):
        """Xác minh mật khẩu thuần túy với mật khẩu đã được băm."""
        return pwd_context.verify(plain_password, hashed_password)

    @staticmethod
    def get_password_hash(password):
        """Băm một mật khẩu thuần túy."""
        print(f"DEBUG Hashing password: '{password}', type: {type(password)}, len: {len(str(password))}")
        return pwd_context.hash(password)

    @staticmethod
    async def register_user(username, email, password, displayName):
        """
        Xử lý đăng ký người dùng mới.
        Kiểm tra tên người dùng/email đã tồn tại, băm mật khẩu và tạo người dùng.
        """
        # Kiểm tra xem người dùng đã tồn tại chưa bằng cách truy vấn bất đồng bộ
        if await User.find_one(User.username == username):
            raise ValueError(f"Tên người dùng '{username}' đã tồn tại.")
        if await User.find_one(User.email == email):
            raise ValueError(f"Email '{email}' đã tồn tại.")

        # Băm mật khẩu (hoạt động đồng bộ)
        hashed_password = AuthService.get_password_hash(password)
        
        # Tạo một thực thể người dùng mới
        # Salt được passlib xử lý tự động và là một phần của chuỗi băm.
        new_user = User(
            username=username,
            email=email,
            hashedPassword=hashed_password,
            displayName=displayName
        )
        
        # Lưu người dùng mới vào cơ sở dữ liệu một cách bất đồng bộ
        await new_user.save()
        return new_user

    @staticmethod
    async def login_user(username, password, device_token: str = None):
        """
        Xử lý đăng nhập của người dùng.
        Tìm người dùng bằng username và xác minh mật khẩu.
        """
        # Tìm người dùng bằng username một cách bất đồng bộ
        user = await User.find_one(User.username == username)
        if not user:
            return None # Không tìm thấy người dùng
        
        # Xác minh mật khẩu (hoạt động đồng bộ)
        if not AuthService.verify_password(password, user.hashedPassword):
            return None # Mật khẩu không hợp lệ
        
        # Cập nhật device token nếu được cung cấp
        if device_token:
            user.deviceToken = device_token
            await user.save()
        return user