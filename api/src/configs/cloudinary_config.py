import cloudinary
from dotenv import load_dotenv
import os

# Load biến môi trường từ file .env
load_dotenv()

def init_cloudinary():
    cloudinary.config(
        cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
        api_key=os.getenv("CLOUDINARY_API_KEY"),
        api_secret=os.getenv("CLOUDINARY_API_SECRET"),
        secure=True
    )
    print("✅ Cloudinary initialized:", os.getenv("CLOUDINARY_CLOUD_NAME"))
