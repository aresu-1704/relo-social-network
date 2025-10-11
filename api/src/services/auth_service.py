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
        return pwd_context.hash(password)

    @staticmethod
    def register_user(username, email, password, displayName):
        """
        Xử lý đăng ký người dùng mới.
        Kiểm tra tên người dùng/email đã tồn tại, băm mật khẩu và tạo người dùng.
        """
        # Kiểm tra xem người dùng đã tồn tại chưa
        if User.find_by_username(username):
            raise ValueError(f"Tên người dùng '{username}' đã tồn tại.")
        if User.find_by_email(email):
            raise ValueError(f"Email '{email}' đã tồn tại.")

        # Băm mật khẩu
        hashed_password = AuthService.get_password_hash(password)
        
        # Lưu ý: Salt được passlib xử lý tự động và là một phần của chuỗi băm.
        # Chúng ta có thể xóa trường 'salt' riêng biệt khỏi mô hình Người dùng nếu chúng ta sử dụng passlib như thế này.
        # Hiện tại, chúng tôi sẽ chuyển một chuỗi trống cho đối số salt.

        new_user = User(
            username=username,
            email=email,
            hashedPassword=hashed_password,
            salt="", # passlib bao gồm salt trong chuỗi băm
            displayName=displayName
        )
        new_user.save()
        return new_user

    @staticmethod
    def login_user(email, password):
        """
        Xử lý đăng nhập của người dùng.
        Tìm người dùng bằng email và xác minh mật khẩu.
        """
        user = User.find_by_email(email)
        if not user:
            return None # Không tìm thấy người dùng
        
        if not AuthService.verify_password(password, user.hashedPassword):
            return None # Mật khẩu không hợp lệ
            
        return user