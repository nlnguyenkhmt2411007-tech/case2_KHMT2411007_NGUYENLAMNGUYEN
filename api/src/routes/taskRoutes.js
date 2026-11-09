
const express = require("express");

const {
  createTask,
  getTasks,
  getTaskById,
  updateTask,
  deleteTask
} = require("../controllers/taskController");

const {
  assignTask
} = require("../controllers/taskAssignmentController");

const {
  requireAuth
} = require("../middleware/authMiddleware");

const {requireTask,requireOwner} = require("../middleware/taskAccess");
const team=require("../controllers/taskTeamController");
const router = express.Router();

// ======================================================
// PHẦN B - QUẢN LÝ CÔNG VIỆC
// ======================================================

// B1. Tạo công việc
// POST /api/tasks
router.post("/", requireAuth, createTask);

// B2 + B6. Danh sách, tìm kiếm, lọc và sắp xếp
// GET /api/tasks
router.get("/", requireAuth, getTasks);

// ======================================================
// PHẦN C - GIAO VIỆC VÀ CHIA SẺ
// ======================================================

// C1. Giao công việc cho một hoặc nhiều người
// POST /api/tasks/:id/assignees
router.post("/:id/assignees", requireAuth, assignTask);

// C2-C6: Xem thành viên, đặt người phụ trách chính, chia sẻ và thu hồi.
router.get("/:id/team",requireAuth,requireTask,team.details);
router.put("/:id/primary",requireAuth,requireTask,requireOwner,team.primary);
router.delete("/:id/assignees/:userId",requireAuth,requireTask,requireOwner,team.removeAssignee);
router.put("/:id/shares",requireAuth,requireTask,requireOwner,team.upsertShares);
router.delete("/:id/shares/:userId",requireAuth,requireTask,requireOwner,team.removeShare);

// ======================================================
// PHẦN B - CHI TIẾT, CHỈNH SỬA VÀ XÓA
// ======================================================

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
