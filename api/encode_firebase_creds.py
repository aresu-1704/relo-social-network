#!/usr/bin/env python3
"""
Script để encode Firebase credentials JSON thành base64
Dùng cho việc deploy lên Vercel
"""
import json
import base64
import sys

def encode_firebase_creds(json_file_path: str):
    """Encode Firebase credentials JSON file thành base64 string"""
    try:
        # Đọc file JSON
        with open(json_file_path, 'r', encoding='utf-8') as f:
            creds_json = json.load(f)
        
        # Convert to JSON string
        json_str = json.dumps(creds_json)
        
        # Encode to base64
        encoded = base64.b64encode(json_str.encode('utf-8')).decode('utf-8')
        
        print("=" * 80)
        print("✅ Firebase Credentials đã được encode thành base64!")
        print("=" * 80)
        print("\nThêm biến môi trường này vào Vercel:")
        print(f"\nFIREBASE_CREDENTIALS_BASE64={encoded}")
        print("\n" + "=" * 80)
        
        return encoded
    except FileNotFoundError:
        print(f"❌ Không tìm thấy file: {json_file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Lỗi parse JSON: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Lỗi: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Default: relo-api.json trong thư mục hiện tại
    json_file = sys.argv[1] if len(sys.argv) > 1 else "relo-api.json"
    encode_firebase_creds(json_file)

