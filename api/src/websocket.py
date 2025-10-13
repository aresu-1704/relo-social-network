# api/src/websocket.py
from typing import Dict, List, Any
from fastapi import WebSocket
from datetime import datetime

class ConnectionManager:
    def __init__(self):
        # Ánh xạ user_id tới danh sách các kết nối WebSocket đang hoạt động
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

    def _serialize_for_json(self, obj: Any) -> Any:
        """Chuyển đổi datetime thành ISO string để gửi qua JSON."""
        if isinstance(obj, datetime):
            return obj.isoformat()
        if isinstance(obj, dict):
            return {k: self._serialize_for_json(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [self._serialize_for_json(v) for v in obj]
        return obj

    async def broadcast_to_user(self, user_id: str, data: dict):
        """Gửi một tin nhắn JSON đến tất cả các kết nối đang hoạt động của một người dùng."""
        if user_id in self.active_connections:
            json_ready_data = self._serialize_for_json(data)
            for connection in self.active_connections[user_id]:
                await connection.send_json(json_ready_data)

# Tạo một instance duy nhất dùng toàn app
manager = ConnectionManager()
