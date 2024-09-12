import os

from faker import Faker
from pymongo import MongoClient

fake = Faker()
def generate_fake_data():
  return {
    "name": fake.name(),
    "email": fake.email(),
    "phone": fake.phone_number(),
    "address": fake.address(),
    "create_on": fake.date_time_this_month()
  }

mongodb_username = os.getenv("MONGO_INITDB_ROOT_USERNAME")
mongodb_password = os.getenv("MONGO_INITDB_ROOT_PASSWORD")
mongodb_database = os.getenv("MONGO_INITDB_DATABASE")
mongodb_uri = f"mongodb://{mongodb_username}:{mongodb_password}@db:27017/"
client = MongoClient(mongodb_uri)
db = client[mongodb_database]
user_logs = db.create_collection("user_logs", check_exists=False)

user_logs.insert_many([generate_fake_data() for _ in range(2_000_000)])
print(user_logs.count_documents({}))