
const mongoose = require("mongoose");
const TaskActivity = require("../models/TaskActivity");

// ======================================================
// E4. SERVICE GHI LICH SU HOAT DONG
// ======================================================

const ALLOWED_ACTIONS = new Set([
  "task_created",
  "task_updated",
  "task_status_changed",
  "task_completed",
  "task_assigned",
  "task_assignee_removed",
  "task_primary_changed",
  "task_shared",
        "task_share_permission_changed",
  "task_share_removed"
]);

async function recordTaskActivity({
  taskId,
  actorId,
  action,
  description,
  metadata = {}
}) {
  try {
    if (
      !mongoose.isObjectIdOrHexString(taskId) ||
      !mongoose.isObjectIdOrHexString(actorId)
    ) {
      throw new Error("Task ID hoặc Actor ID không hợp lệ");
    }

    if (!ALLOWED_ACTIONS.has(action)) {
      throw new Error("Loại hoạt động không hợp lệ");
    }

    if (
      typeof description !== "string" ||
      description.trim().length === 0 ||
      description.trim().length > 1000
    ) {
      throw new Error("Nội dung lịch sử không hợp lệ");
    }

    const safeMetadata =
      metadata &&
      typeof metadata === "object" &&
      !Array.isArray(metadata)
        ? metadata
        : {};

    const activity = await TaskActivity.create({
      taskId,
      actorId,
      action,
      description: description.trim(),
      metadata: safeMetadata
    });

    return {
      success: true,
      activity
    };
  } catch (error) {
    console.error(
      "[E4] Không thể ghi lịch sử:",
      error.message
    );

    return {
      success: false,
      message: "Không thể ghi lịch sử hoạt động"
    };
  }
}

module.exports = {
  recordTaskActivity
};
