
const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// API kiểm tra backend
app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Task Manager API is running"
  });
});

// API xác thực tài khoản
app.use("/api/auth", authRoutes);

// Xử lý đường dẫn không tồn tại
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "API endpoint not found"
  });
});

module.exports = app;
