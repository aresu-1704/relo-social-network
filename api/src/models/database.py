import os
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Database:
    """
    A class to manage the connection to the MongoDB Atlas database.
    """
    client = None
    db = None

    @staticmethod
    def connect():
        """
        Connects to the MongoDB database using the URI from the environment variables.
        """
        if Database.client is None:
            try:
                # The .env file should be structured as follows:
                # MONGO_URI=mongodb+srv://<username>:<password>@<cluster-url>/
                mongo_uri = os.getenv("MONGO_URI")
                if not mongo_uri:
                    raise ValueError("MONGO_URI not found in environment variables.")
                
                Database.client = MongoClient(mongo_uri)
                # You can specify a default database name here if you want
                # For example: Database.db = Database.client['your_db_name']
                Database.db = Database.client['relo-social-network'] # Example database name
                print("Successfully connected to MongoDB Atlas!")

            except Exception as e:
                print(f"Error connecting to MongoDB: {e}")

    @staticmethod
    def get_database():
        """
        Returns the database object.
        """
        if Database.db is None:
            Database.connect()
        return Database.db

    @staticmethod
    def close():
        """
        Closes the MongoDB connection.
        """
        if Database.client:
            Database.client.close()
            Database.client = None
            Database.db = None
            print("MongoDB connection closed.")
