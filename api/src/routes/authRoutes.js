
const express = require("express");

const {
  register,
  login,
  getMe,
  updateMe,
  changePassword
} = require("../controllers/authController");

const {
  requireAuth
} = require("../middleware/authMiddleware");

const router = express.Router();

// 1. Đăng ký tài khoản
router.post("/register", register);

// 2. Đăng nhập và tạo JWT
router.post("/login", login);

// 3. Xem thông tin cá nhân
router.get("/me", requireAuth, getMe);

// 4. Cập nhật thông tin cá nhân
router.patch("/me", requireAuth, updateMe);

// 5. Đổi mật khẩu
router.patch(
  "/change-password",
  requireAuth,
  changePassword
);

module.exports = router;
