# Nhập các thư viện cần thiết
import os
from motor.motor_asyncio import AsyncIOMotorClient # Thư viện bất đồng bộ cho MongoDB
from beanie import init_beanie # ODM (Object-Document Mapper) cho MongoDB
from dotenv import load_dotenv # Để tải các biến môi trường từ file .env
from typing import Type

# Nhập các model từ các file khác
from .user import User
from .conversation import Conversation
from .message import Message
from .post import Post
from .friend_request import FriendRequest

# Danh sách các model Beanie sẽ được khởi tạo
# Thêm tất cả các model của bạn vào đây
DOCUMENT_MODELS: list[Type] = [User, Conversation, Message, Post, FriendRequest]

async def init_db():
    """
    Khởi tạo kết nối cơ sở dữ liệu và Beanie ODM.
    Hàm này nên được gọi khi FastAPI khởi động.
    """
    # Tải các biến môi trường từ file .env
    load_dotenv()
    # Lấy chuỗi kết nối MongoDB từ biến môi trường
    mongo_uri = os.getenv("MONGO_URI")
    # Nếu không tìm thấy chuỗi kết nối, báo lỗi
    if not mongo_uri:
        raise ValueError("Không tìm thấy MONGO_URI trong các biến môi trường.")

    # Tạo một client kết nối đến MongoDB
    client = AsyncIOMotorClient(mongo_uri)
    # Lấy cơ sở dữ liệu có tên "relo-social-network" (hoặc có thể lấy từ biến môi trường)
    database = client.get_database("relo-social-network")

    # Khởi tạo Beanie với cơ sở dữ liệu và các model đã định nghĩa
    await init_beanie(
        database=database,
        document_models=DOCUMENT_MODELS
    )
    # In thông báo khi kết nối và khởi tạo thành công
    print("Kết nối thành công đến MongoDB và khởi tạo Beanie!")
