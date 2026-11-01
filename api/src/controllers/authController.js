
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");

// ======================================================
// 1. ĐĂNG KÝ TÀI KHOẢN
// POST /api/auth/register
// ======================================================

async function register(req, res) {
  try {
    const { fullName, email, password } = req.body || {};

    if (
      typeof fullName !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "Vui lòng nhập đầy đủ họ tên, email và mật khẩu"
      });
    }

    const name = fullName.trim();
    const normalizedEmail = email.trim().toLowerCase();

    if (!name || !normalizedEmail || !password) {
      return res.status(400).json({
        success: false,
        message: "Không được để trống thông tin đăng ký"
      });
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return res.status(400).json({
        success: false,
        message: "Email không hợp lệ"
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Mật khẩu phải có ít nhất 8 ký tự"
      });
    }

    const existingUser = await User.findOne({
      email: normalizedEmail
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: "Email đã được đăng ký"
      });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await User.create({
      fullName: name,
      email: normalizedEmail,
      passwordHash
    });

    return res.status(201).json({
      success: true,
      message: "Đăng ký tài khoản thành công",
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "Email đã được đăng ký"
      });
    }

    console.error("Register error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể đăng ký tài khoản"
    });
  }
}

// ======================================================
// 2. ĐĂNG NHẬP VÀ TẠO JWT
// POST /api/auth/login
// ======================================================

async function login(req, res) {
  try {
    const { email, password } = req.body || {};

    if (
      typeof email !== "string" ||
      typeof password !== "string" ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        success: false,
        message: "Vui lòng nhập email và mật khẩu"
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({
      email: normalizedEmail
    }).select("+passwordHash");

    const invalidCredentials = {
      success: false,
      message: "Email hoặc mật khẩu không chính xác"
    };

    if (!user || !user.passwordHash) {
      return res.status(401).json(invalidCredentials);
    }

    const passwordMatches = await bcrypt.compare(
      password,
      user.passwordHash
    );

    if (!passwordMatches) {
      return res.status(401).json(invalidCredentials);
    }

    if (
      typeof process.env.JWT_SECRET !== "string" ||
      !process.env.JWT_SECRET.trim()
    ) {
      console.error("JWT_SECRET chưa được cấu hình");

      return res.status(500).json({
        success: false,
        message: "Máy chủ chưa sẵn sàng xác thực"
      });
    }

    const token = jwt.sign(
      { sub: user._id.toString() },
      process.env.JWT_SECRET,
      {
        expiresIn: "1d",
        algorithm: "HS256"
      }
    );

    return res.status(200).json({
      success: true,
      message: "Đăng nhập thành công",
      token,
      tokenType: "Bearer",
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl || ""
      }
    });
  } catch (error) {
    console.error("Login error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể đăng nhập tài khoản"
    });
  }
}

// ======================================================
// 3. XEM THÔNG TIN CÁ NHÂN
// GET /api/auth/me
// ======================================================

async function getMe(req, res) {
  try {
    const user = req.user;

    return res.status(200).json({
      success: true,
      message: "Lấy thông tin cá nhân thành công",
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl || "",
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    console.error("Get me error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể lấy thông tin cá nhân"
    });
  }
}

// ======================================================
// 4. CẬP NHẬT THÔNG TIN CÁ NHÂN
// PATCH /api/auth/me
// ======================================================

async function updateMe(req, res) {
  try {
    const { fullName } = req.body || {};

    if (typeof fullName !== "string") {
      return res.status(400).json({
        success: false,
        message: "Vui lòng nhập họ và tên"
      });
    }

    const name = fullName.trim();

    if (name.length < 2 || name.length > 100) {
      return res.status(400).json({
        success: false,
        message: "Họ và tên phải có từ 2 đến 100 ký tự"
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: { fullName: name } },
      {
        new: true,
        runValidators: true
      }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy tài khoản"
      });
    }

    return res.status(200).json({
      success: true,
      message: "Cập nhật thông tin cá nhân thành công",
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl || "",
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  } catch (error) {
    console.error("Update me error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể cập nhật thông tin cá nhân"
    });
  }
}

// ======================================================
// 5. ĐỔI MẬT KHẨU
// PATCH /api/auth/change-password
// ======================================================

async function changePassword(req, res) {
  try {
    const { currentPassword, newPassword } = req.body || {};

    // Kiểm tra dữ liệu đầu vào.
    if (
      typeof currentPassword !== "string" ||
      typeof newPassword !== "string" ||
      !currentPassword ||
      !newPassword
    ) {
      return res.status(400).json({
        success: false,
        message: "Vui lòng nhập mật khẩu hiện tại và mật khẩu mới"
      });
    }

    // Mật khẩu mới phải đủ độ dài.
    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Mật khẩu mới phải có ít nhất 8 ký tự"
      });
    }

    if (newPassword === currentPassword) {
      return res.status(400).json({
        success: false,
        message: "Mật khẩu mới phải khác mật khẩu hiện tại"
      });
    }

    // Lấy tài khoản theo JWT đã được xác thực.
    // passwordHash có select: false nên phải chọn thủ công.
    const user = await User.findById(
      req.user._id
    ).select("+passwordHash");

    if (!user || !user.passwordHash) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy tài khoản"
      });
    }

    // Xác minh mật khẩu hiện tại.
    const passwordMatches = await bcrypt.compare(
      currentPassword,
      user.passwordHash
    );

    if (!passwordMatches) {
      return res.status(400).json({
        success: false,
        message: "Mật khẩu hiện tại không chính xác"
      });
    }

    // Không cho đặt lại mật khẩu cũ.
    const sameAsOld = await bcrypt.compare(
      newPassword,
      user.passwordHash
    );

    if (sameAsOld) {
      return res.status(400).json({
        success: false,
        message: "Mật khẩu mới phải khác mật khẩu hiện tại"
      });
    }

    // Mã hóa và lưu mật khẩu mới vào MongoDB Atlas.
    user.passwordHash = await bcrypt.hash(newPassword, 12);

    await user.save();

    return res.status(200).json({
      success: true,
      message: "Đổi mật khẩu thành công. Vui lòng đăng nhập lại."
    });
  } catch (error) {
    console.error("Change password error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể đổi mật khẩu"
    });
  }
}

// ======================================================
// XUẤT CÁC HÀM CONTROLLER
// ======================================================

module.exports = {
  register,
  login,
  getMe,
  updateMe,
  changePassword
};
