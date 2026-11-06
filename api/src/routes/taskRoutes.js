
const express = require("express");

const {
  createTask,
  getTasks,
  getTaskById,
  updateTask,
  deleteTask
} = require("../controllers/taskController");

const {
  requireAuth
} = require("../middleware/authMiddleware");

const router = express.Router();

// ======================================================
// PHẦN B - QUẢN LÝ CÔNG VIỆC
// ======================================================

// B1. Tạo công việc
// POST /api/tasks
router.post("/", requireAuth, createTask);

// B2. Xem danh sách công việc
// GET /api/tasks
router.get("/", requireAuth, getTasks);

// B3. Xem chi tiết công việc
// GET /api/tasks/:id
router.get("/:id", requireAuth, getTaskById);

// B4. Chỉnh sửa công việc
// PATCH /api/tasks/:id
router.patch("/:id", requireAuth, updateTask);

// B5. Xóa công việc
// DELETE /api/tasks/:id
router.delete("/:id", requireAuth, deleteTask);

module.exports = router;
