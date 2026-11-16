
const mongoose = require("mongoose");

// ======================================================
// E4. LICH SU HOAT DONG CONG VIEC
// MongoDB collection: task_activities
// ======================================================

const taskActivitySchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      required: true,
      index: true
    },

    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true
    },

    action: {
      type: String,
      required: true,
      enum: [
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
      ]
    },

    description: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000
    },

    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {}
    }
  },
  {
    timestamps: true,
    collection: "task_activities"
  }
);

// Sap xep lich su moi nhat truoc.
taskActivitySchema.index({
  taskId: 1,
  createdAt: -1,
  _id: -1
});

module.exports = mongoose.model(
  "TaskActivity",
  taskActivitySchema
);
