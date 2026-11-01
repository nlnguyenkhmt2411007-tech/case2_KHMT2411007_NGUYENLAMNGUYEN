
const jwt = require("jsonwebtoken");
const User = require("../models/User");

async function requireAuth(req, res, next) {
  try {
    const authorization = req.headers.authorization;

    if (typeof authorization !== "string") {
      return res.status(401).json({
        success: false,
        message: "Bạn cần đăng nhập để tiếp tục"
      });
    }

    const match = authorization.match(/^Bearer\s+(\S+)$/i);

    if (!match) {
      return res.status(401).json({
        success: false,
        message: "Token xác thực không hợp lệ"
      });
    }

    if (!process.env.JWT_SECRET) {
      console.error("JWT_SECRET chưa được cấu hình");

      return res.status(500).json({
        success: false,
        message: "Máy chủ chưa sẵn sàng xác thực"
      });
    }

    let decoded;

    try {
      decoded = jwt.verify(match[1], process.env.JWT_SECRET, {
        algorithms: ["HS256"]
      });
    } catch {
      return res.status(401).json({
        success: false,
        message: "Phiên đăng nhập không hợp lệ hoặc đã hết hạn"
      });
    }

    if (
      !decoded ||
      typeof decoded !== "object" ||
      typeof decoded.sub !== "string"
    ) {
      return res.status(401).json({
        success: false,
        message: "Token xác thực không hợp lệ"
      });
    }

    const user = await User.findById(decoded.sub);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Tài khoản không còn tồn tại"
      });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === "CastError") {
      return res.status(401).json({
        success: false,
        message: "Token xác thực không hợp lệ"
      });
    }

    console.error("Auth middleware error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể xác thực tài khoản"
    });
  }
}

module.exports = {
  requireAuth
};
