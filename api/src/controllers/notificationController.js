
const mongoose = require("mongoose");

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

// ======================================================
// D5. DANH DAU MOT THONG BAO DA DOC
// PATCH /api/notifications/:id/read
// ======================================================

async function markNotificationRead(req, res) {
  try {
    const notificationId = req.params.id;

    if (!mongoose.isObjectIdOrHexString(notificationId)) {
      return res.status(400).json({
        success: false,
        message: "ID thong bao khong hop le"
      });
    }

    const notification = await Notification.findOneAndUpdate(
      {
        _id: notificationId,
        recipientId: req.user._id
      },
      {
        $set: {
          isRead: true,
          readAt: new Date()
        }
      },
      {
        new: true
      }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Khong tim thay thong bao"
      });
    }

    return res.status(200).json({
      success: true,
      message: "Da danh dau thong bao da doc",
      notification
    });
  } catch (error) {
    console.error(
      "Mark notification read error:",
      error.message
    );

    return res.status(500).json({
      success: false,
      message: "Khong the cap nhat thong bao"
    });
  }
}

module.exports = {
  getNotifications,
  markNotificationRead
};
