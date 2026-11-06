
const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");
const taskRoutes = require("./routes/taskRoutes");

const app = express();

// ======================================================
// 1. MIDDLEWARE
// ======================================================

app.use(cors());
app.use(express.json());

// ======================================================
// 2. API KIỂM TRA BACKEND
// GET /api/health
// ======================================================

app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Task Manager API is running"
  });
});

// ======================================================
// 3. PHẦN A - QUẢN LÝ TÀI KHOẢN VÀ XÁC THỰC
// ======================================================

app.use("/api/auth", authRoutes);

// ======================================================
// 4. PHẦN B - QUẢN LÝ CÔNG VIỆC
// ======================================================

// POST /api/tasks
// Tạo công việc mới, yêu cầu JWT hợp lệ.
app.use("/api/tasks", taskRoutes);

// ======================================================
// 5. XỬ LÝ ĐƯỜNG DẪN KHÔNG TỒN TẠI
// ======================================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "API endpoint not found"
  });
});

module.exports = app;
