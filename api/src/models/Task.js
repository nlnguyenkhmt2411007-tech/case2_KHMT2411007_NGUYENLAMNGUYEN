
const mongoose = require("mongoose");

// ======================================================
// MODEL TASK - CASE STUDY 2 TASK MANAGER
// B: Quản lý công việc
// C1: Giao công việc cho nhiều người
// ======================================================

const taskSchema = new mongoose.Schema(
  {
    // Tên công việc
    title: {
      type: String,
      required: [true, "Vui lòng nhập tên công việc"],
      trim: true,
      minlength: [2, "Tên công việc phải có ít nhất 2 ký tự"],
      maxlength: [200, "Tên công việc tối đa 200 ký tự"]
    },

    // Mô tả công việc
    description: {
      type: String,
      default: "",
      trim: true,
      maxlength: [5000, "Mô tả tối đa 5000 ký tự"]
    },

    // Trạng thái
    status: {
      type: String,
      enum: [
        "chua_thuc_hien",
        "dang_thuc_hien",
        "da_hoan_thanh"
      ],
      default: "chua_thuc_hien"
    },

    // Mức độ ưu tiên
    priority: {
      type: String,
      enum: ["thap", "trung_binh", "cao"],
      default: "trung_binh"
    },

    // Ngày bắt đầu
    startDate: {
      type: Date,
      default: null
    },

    // Hạn hoàn thành
    dueDate: {
      type: Date,
      default: null
    },

    // Người tạo công việc
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Công việc phải có người tạo"],
      index: true
    },

    primaryAssigneeId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    shares: {
      type: [{
        userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
        role: { type: String, enum: ["viewer", "editor"], required: true }
      }], default: []
    },

    // ==================================================
    // C1. DANH SÁCH NGƯỜI ĐƯỢC GIAO CÔNG VIỆC
    // ==================================================

    assigneeIds: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User"
        }
      ],
      default: [],
      validate: {
        validator: function (ids) {
          if (!Array.isArray(ids)) return false;

          const values = ids.map((id) =>
            String(id).toLowerCase()
          );

          return new Set(values).size === values.length;
        },
        message: "Danh sách người được giao bị trùng"
      }
    }
  },
  {
    timestamps: true,
    collection: "tasks"
  }
);

// ======================================================
// KIỂM TRA NGÀY
// ======================================================

taskSchema.pre("validate", function () {
  if (
    this.startDate &&
    this.dueDate &&
    this.dueDate < this.startDate
  ) {
    this.invalidate(
      "dueDate",
      "Hạn hoàn thành không được trước ngày bắt đầu"
    );
  }
});

// ======================================================
// INDEX
// ======================================================

taskSchema.index({
  createdBy: 1,
  createdAt: -1
});

taskSchema.index({
  status: 1,
  priority: 1
});

taskSchema.index({ primaryAssigneeId: 1 });
taskSchema.index({ "shares.userId": 1 });

// C1: Hỗ trợ tìm kiếm công việc được giao.
taskSchema.index({
  assigneeIds: 1,
  createdAt: -1
});

// ======================================================
// EXPORT MODEL
// ======================================================

module.exports = mongoose.model("Task", taskSchema);
