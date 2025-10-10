from fastapi import FastAPI

app = FastAPI()

# Import routers here

@app.get("/")
def read_root():
    return {"message": "Server is running"}