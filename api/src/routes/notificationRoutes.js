const express = require("express");

const {
  requireAuth
} = require("../middleware/authMiddleware");

const {
  getNotifications
} = require("../controllers/notificationController");

const router = express.Router();

// Tat ca API thong bao deu yeu cau dang nhap.
router.use(requireAuth);

// D4: Danh sach thong bao cua tai khoan hien tai.
router.get("/", getNotifications);

module.exports = router;
