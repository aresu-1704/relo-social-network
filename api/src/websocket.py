# api/src/websocket.py
from typing import Dict, List
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Ánh xạ user_id tới danh sách các kết nối WebSocket đang hoạt động của họ
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        """Đăng ký một kết nối WebSocket mới cho một người dùng."""
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket):
        """Xóa một kết nối WebSocket."""
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def broadcast_to_user(self, user_id: str, data: dict):
        """Gửi một tin nhắn JSON đến tất cả các kết nối đang hoạt động của một người dùng cụ thể."""
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_json(data)

# Tạo một phiên bản duy nhất của trình quản lý để sử dụng trên toàn bộ ứng dụng
manager = ConnectionManager()