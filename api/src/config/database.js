
const mongoose = require("mongoose");

async function connectDatabase() {
  try {
    if (!process.env.MONGODB_URI) {
      throw new Error("Chưa cấu hình MONGODB_URI trong file .env");
    }

    await mongoose.connect(process.env.MONGODB_URI, {
      dbName: "task_manager",
      serverSelectionTimeoutMS: 15000
    });

    console.log("Kết nối MongoDB Atlas thành công!");
    console.log(`Database: ${mongoose.connection.name}`);
  } catch (error) {
    console.error("Kết nối MongoDB thất bại:", error.message);
    throw error;
  }
}

module.exports = connectDatabase;
