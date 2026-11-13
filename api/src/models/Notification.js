
const mongoose = require("mongoose");

// ======================================================
// D. THONG BAO QUA EMAIL VA TRONG UNG DUNG
// ======================================================

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

    // D5: Lien ket thong bao voi ban ghi nhac han.
    // Khong bat buoc de giu tuong thich thong bao cu.
    reminderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DueReminder",
      default: undefined
    },

    type: {
      type: String,
      enum: [
        "task_assigned",
        "task_shared",
        "task_status_changed",

        // D5: Nhac nho cong viec sap den han
        "task_due_reminder"
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

// ======================================================
// INDEX
// ======================================================

// Lay danh sach thong bao theo nguoi nhan.
notificationSchema.index({
  recipientId: 1,
  createdAt: -1
});

// Loc thong bao chua doc / da doc.
notificationSchema.index({
  recipientId: 1,
  isRead: 1
});

// Tim thong bao theo cong viec.
notificationSchema.index({
  taskId: 1
});

// ======================================================
// D5. CHONG TAO THONG BAO NHAC HAN TRUNG LAP
// ======================================================

// Moi ban ghi nhac han chi co toi da mot thong bao.
// Cac thong bao cu khong co reminderId se khong
// bi anh huong boi unique index nay.
notificationSchema.index(
  {
    reminderId: 1
  },
  {
    unique: true,
    name: "unique_due_reminder_notification",
    partialFilterExpression: {
      reminderId: {
        $type: "objectId"
      }
    }
  }
);

// ======================================================
// EXPORT MODEL
// ======================================================

module.exports = mongoose.model(
  "Notification",
  notificationSchema
);
