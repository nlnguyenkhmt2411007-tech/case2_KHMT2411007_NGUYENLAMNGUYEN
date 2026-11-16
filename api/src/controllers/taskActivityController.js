const TaskActivity = require("../models/TaskActivity");

// ======================================================
// E4. LAY LICH SU HOAT DONG CUA CONG VIEC
// GET /api/tasks/:id/activities
// ======================================================

async function getTaskActivities(req, res) {
  try {
    const taskId = req.task._id;

    const activities = await TaskActivity.find({ taskId })
      .populate("actorId", "fullName email")
      .sort({ createdAt: -1, _id: -1 })
      .lean();

    return res.status(200).json({
      success: true,
      message: "Lay lich su hoat dong thanh cong",
      count: activities.length,
      data: activities
    });
  } catch (error) {
    console.error(
      "[E4] Get task activities error:",
      error.message
    );

    return res.status(500).json({
      success: false,
      message: "Khong the lay lich su hoat dong"
    });
  }
}

module.exports = {
  getTaskActivities
};
