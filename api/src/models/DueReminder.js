
const mongoose = require("mongoose");

// ======================================================
// D8. LUU TRANG THAI NHAC HAN CONG VIEC
// ======================================================

const dueReminderSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      required: true,
      index: true
    },

    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },

    // Luu moc han de ho tro nhac lai khi dueDate thay doi.
    dueDate: {
      type: Date,
      required: true
    },

    // So gio nhac truoc han.
    hoursBefore: {
      type: Number,
      required: true,
      default: 24,
      min: 1
    },

    // Theo doi thong bao trong ung dung.
    inAppStatus: {
      type: String,
      enum: ["pending", "processing", "sent", "failed"],
      default: "pending"
    },

    inAppSentAt: {
      type: Date,
      default: null
    },

    // Theo doi ket qua gui email.
    emailStatus: {
      type: String,
      enum: ["pending", "processing", "sent", "failed"],
      default: "pending"
    },

    emailSentAt: {
      type: Date,
      default: null
    },

    // So lan thu gui email.
    emailAttempts: {
      type: Number,
      default: 0,
      min: 0
    },

    // Thoi diem thu gui gan nhat.
    lastAttemptAt: {
      type: Date,
      default: null
    },

    // Thong tin loi ngan gon, khong luu mat khau SMTP.
    lastError: {
      type: String,
      default: null,
      maxlength: 500
    }
  },
  {
    timestamps: true,
    collection: "due_reminders"
  }
);

// Moi nguoi chi co mot ban ghi cho tung moc han va muc nhac.
dueReminderSchema.index(
  {
    taskId: 1,
    recipientId: 1,
    dueDate: 1,
    hoursBefore: 1
  },
  {
    unique: true,
    name: "unique_due_reminder"
  }
);

// Tim nhanh cac muc can xu ly.
dueReminderSchema.index({
  inAppStatus: 1,
  emailStatus: 1
});

module.exports = mongoose.model(
  "DueReminder",
  dueReminderSchema
);
