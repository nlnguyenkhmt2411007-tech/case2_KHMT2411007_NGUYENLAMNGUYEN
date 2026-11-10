const Notification = require("../models/Notification");

// ======================================================
// D4. LAY DANH SACH THONG BAO CUA NGUOI DANG NHAP
// GET /api/notifications
// ======================================================

async function getNotifications(req, res) {
  try {
    const recipientId = req.user._id;

    const notifications = await Notification.find({
      recipientId
    })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate("actorId", "fullName email")
      .populate("taskId", "title")
      .lean();

    const unreadCount = await Notification.countDocuments({
      recipientId,
      isRead: false
    });

    return res.status(200).json({
      success: true,
      unreadCount,
      total: notifications.length,
      notifications
    });
  } catch (error) {
    console.error(
      "Get notifications error:",
      error.message
    );

    return res.status(500).json({
      success: false,
      message: "Khong the lay danh sach thong bao"
    });
  }
}

module.exports = {
  getNotifications
};
