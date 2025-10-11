from fastapi import FastAPI
from .routers import auth_router, user_router, post_router, message_router
from .models import init_db

# Khởi tạo app FastAPI với thông tin Swagger UI
app = FastAPI(
    title="Relo Social Network",
    description="Backend mạng xã hội nhắn tin trực tuyến **Relo**.\n\n"
                "Hệ thống hỗ trợ đăng ký, đăng nhập, kết bạn, nhắn tin thời gian thực "
                "và quản lý bài viết cá nhân.",
    version="1.0.1"
)

# Kết nối với cơ sở dữ liệu khi khởi động
@app.on_event("startup")
async def startup_db_client():
    await init_db()

# Gắn các router
app.include_router(auth_router.router)
app.include_router(user_router.router)
app.include_router(post_router.router)
app.include_router(message_router.router)

@app.get("/")
def read_root():
    return {"message": "Máy chủ đang chạy"}
