
const mongoose = require("mongoose");

const Task = require("../models/Task");
const User = require("../models/User");

// ======================================================
// C1. GIAO CÔNG VIỆC CHO MỘT HOẶC NHIỀU NGƯỜI
// POST /api/tasks/:id/assignees
// ======================================================

async function assignTask(req, res) {
  try {
    const taskId = req.params.id;

    // 1. Kiểm tra ID công việc.
    if (
      typeof taskId !== "string" ||
      !mongoose.isObjectIdOrHexString(taskId)
    ) {
      return res.status(400).json({
        success: false,
        message: "ID công việc không hợp lệ"
      });
    }

    // 2. Kiểm tra dữ liệu được gửi lên.
    const body = req.body;

    if (
      !body ||
      typeof body !== "object" ||
      Array.isArray(body) ||
      !Array.isArray(body.emails)
    ) {
      return res.status(400).json({
        success: false,
        message: "Vui lòng cung cấp danh sách email"
      });
    }

    const emails = body.emails;

    if (emails.length === 0 || emails.length > 20) {
      return res.status(400).json({
        success: false,
        message: "Mỗi lần giao từ 1 đến 20 người"
      });
    }

    // 3. Chuẩn hóa email.
    const normalizedEmails = [];

    for (const email of emails) {
      if (
        typeof email !== "string" ||
        email.trim().length === 0 ||
        email.length > 254
      ) {
        return res.status(400).json({
          success: false,
          message: "Danh sách email không hợp lệ"
        });
      }

      const normalized = email.trim().toLowerCase();

      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
        return res.status(400).json({
          success: false,
          message: `Email không hợp lệ: ${normalized}`
        });
      }

      normalizedEmails.push(normalized);
    }

    // 4. Không cho phép email trùng trong một yêu cầu.
    const uniqueEmails = [...new Set(normalizedEmails)];

    if (uniqueEmails.length !== normalizedEmails.length) {
      return res.status(400).json({
        success: false,
        message: "Danh sách email có người nhận bị trùng"
      });
    }

    // 5. Chỉ người tạo công việc có quyền giao.
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.user._id
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy công việc hoặc không có quyền giao"
      });
    }

    // 6. Tìm tài khoản tương ứng với email.
    const users = await User.find({
      email: { $in: uniqueEmails }
    })
      .select("_id fullName email")
      .lean();

    if (users.length !== uniqueEmails.length) {
      const foundEmails = new Set(
        users.map((user) => user.email)
      );

      const missingEmails = uniqueEmails.filter(
        (email) => !foundEmails.has(email)
      );

      return res.status(400).json({
        success: false,
        message: "Một hoặc nhiều tài khoản chưa tồn tại",
        missingEmails
      });
    }

    // 7. Không giao cho chính người tạo.
    const creatorId = String(req.user._id);

    if (
      users.some(
        (user) => String(user._id) === creatorId
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "Không thể tự giao công việc cho chính mình"
      });
    }

    // 8. Kiểm tra những người đã được giao trước đó.
    const existingIds = new Set(
      (task.assigneeIds || []).map((id) => String(id))
    );

    const duplicateUsers = users.filter(
      (user) => existingIds.has(String(user._id))
    );

    if (duplicateUsers.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Một hoặc nhiều người đã được giao công việc",
        duplicateEmails: duplicateUsers.map(
          (user) => user.email
        )
      });
    }

    // 9. Thêm người được giao bằng thao tác nguyên tử.
    // $addToSet ngăn ID trùng ngay cả khi có yêu cầu đồng thời.
    const updatedTask = await Task.findOneAndUpdate(
      {
        _id: taskId,
        createdBy: req.user._id
      },
      {
        $addToSet: {
          assigneeIds: {
            $each: users.map((user) => user._id)
          }
        }
      },
      {
        new: true,
        runValidators: true
      }
    );

    if (!updatedTask) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy công việc"
      });
    }

    // 10. Trả về danh sách người được giao.
    const assignedUsers = await User.find({
      _id: { $in: updatedTask.assigneeIds }
    })
      .select("_id fullName email")
      .lean();

    res.status(200).json({
      success: true,
      message: "Giao công việc thành công",
      taskId: updatedTask._id,
      totalAssignees: assignedUsers.length,
      assignees: assignedUsers
    });
    // D: Lưu thông báo in-app, tùy chọn gửi email khi cấu hình SMTP.
  } catch (error) {
    if (error.name === "ValidationError") {
      return res.status(400).json({
        success: false,
        message: "Dữ liệu giao việc không hợp lệ"
      });
    }

    console.error("Assign task error:", error.message);

    if (res.headersSent) return;
    return res.status(500).json({
      success: false,
      message: "Không thể giao công việc"
    });
  }
}

module.exports = {
  assignTask
};
