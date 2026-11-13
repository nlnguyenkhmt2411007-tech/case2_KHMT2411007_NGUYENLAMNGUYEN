
const mongoose = require("mongoose");

// ======================================================
// D6. LUU LICH SU GUI EMAIL THANH CONG / THAT BAI
// ======================================================

const emailLogSchema = new mongoose.Schema(
  {
    // Loai su kien gui email.
    eventType: {
      type: String,
      required: true,
      enum: [
        "task_assigned",
        "task_shared",
        "task_status_changed",
        "task_due_reminder",
        "task_due_date_changed"
      ]
    },

    // Cong viec lien quan.
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      default: null
    },

    // Nguoi thuc hien thao tac, neu co.
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    },

    // Nguoi nhan email.
    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    },

    recipientEmail: {
      type: String,
      required: true,
      trim: true,
      lowercase: true
    },

    // Thong tin email.
    subject: {
      type: String,
      required: true,
      trim: true
    },

    // Ket qua gui email.
    status: {
      type: String,
      required: true,
      enum: ["sent", "failed"]
    },

    // Thoi diem thu gui.
    attemptedAt: {
      type: Date,
      required: true,
      default: Date.now
    },

    // Thoi diem SMTP chap nhan email.
    sentAt: {
      type: Date,
      default: null
    },

    // Ma loi neu gui that bai.
    errorCode: {
      type: String,
      default: null
    },

    // ID email tra ve tu SMTP.
    messageId: {
      type: String,
      default: null
    }
  },
  {
    timestamps: true,
    collection: "email_logs"
  }
);

// Tim lich su theo cong viec.
emailLogSchema.index({
  taskId: 1,
  createdAt: -1
});

// Tim lich su theo nguoi nhan.
emailLogSchema.index({
  recipientId: 1,
  createdAt: -1
});

// Loc theo ket qua gui.
emailLogSchema.index({
  status: 1,
  createdAt: -1
});

module.exports = mongoose.model(
  "EmailLog",
  emailLogSchema
);
