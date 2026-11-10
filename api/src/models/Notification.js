
const mongoose = require("mongoose");

// D. Thong bao qua email va trong ung dung
const notificationSchema = new mongoose.Schema(
  {
    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },

    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    },

    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      required: true
    },

    type: {
      type: String,
      enum: [
        "task_assigned",
        "task_shared",
        "task_status_changed"
      ],
      required: true
    },

    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200
    },

    message: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000
    },

    isRead: {
      type: Boolean,
      default: false
    },

    readAt: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true,
    collection: "notifications"
  }
);

notificationSchema.index({
  recipientId: 1,
  createdAt: -1
});

notificationSchema.index({
  recipientId: 1,
  isRead: 1
});

notificationSchema.index({
  taskId: 1
});

module.exports = mongoose.model(
  "Notification",
  notificationSchema
);
