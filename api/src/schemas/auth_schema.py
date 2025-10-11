from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    displayName: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserPublic(BaseModel):
    id: str
    username: str
    email: EmailStr
    displayName: str

    class Config:
        orm_mode = True
        # This is to help pydantic convert non-dict objects into pydantic models
        # We need a custom json_encoders for ObjectId
        json_encoders = {
            'id': lambda v: str(v) # Convert ObjectId to string
        }
