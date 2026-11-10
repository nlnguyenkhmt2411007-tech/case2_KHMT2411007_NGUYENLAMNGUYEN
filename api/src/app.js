
const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");
const taskRoutes = require("./routes/taskRoutes");

// ======================================================
// D4-D5. ROUTES THONG BAO
// ======================================================

const notificationRoutes = require("./routes/notificationRoutes");

const app = express();

// ======================================================
// 1. MIDDLEWARE
// ======================================================

app.use(cors());
app.use(express.json());

// ======================================================
// 2. API KIEM TRA BACKEND
// GET /api/health
// ======================================================

app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Task Manager API is running"
  });
});

// ======================================================
// 3. PHAN A - QUAN LY TAI KHOAN VA XAC THUC
// ======================================================

app.use("/api/auth", authRoutes);

// ======================================================
// 4. PHAN B-C - QUAN LY CONG VIEC, GIAO VIEC, CHIA SE
// ======================================================

app.use("/api/tasks", taskRoutes);

// ======================================================
// 5. PHAN D - THONG BAO TRONG UNG DUNG
// ======================================================

// GET /api/notifications
// PATCH /api/notifications/:id/read
// Tat ca yeu cau JWT hop le.
app.use("/api/notifications", notificationRoutes);

// ======================================================
// 6. XU LY DUONG DAN KHONG TON TAI
// ======================================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "API endpoint not found"
  });
});

module.exports = app;
