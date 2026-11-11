
const User = require("../models/User");
const { eq } = require("../middleware/taskAccess");

const {
  notifyTaskShared
} = require("../services/notificationService");

// ======================================================
// D7. SERVICE GUI EMAIL KHI CHIA SE CONG VIEC
// ======================================================

const {
  sendTaskEventEmails
} = require("../services/emailService");

const normalize = email =>
  typeof email === "string"
    ? email.trim().toLowerCase()
    : "";

const pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const goodList = emails =>
  Array.isArray(emails) &&
  emails.length > 0 &&
  emails.length <= 20 &&
  emails.every(
    e =>
      typeof e === "string" &&
      normalize(e).length <= 254 &&
      pattern.test(normalize(e))
  ) &&
  new Set(emails.map(normalize)).size === emails.length;

async function resolveUsers(emails, res) {
  if (!goodList(emails)) {
    res.status(400).json({
      success: false,
      message: "Danh sách email không hợp lệ, trùng hoặc quá 20 người"
    });
    return null;
  }

  const normalized = emails.map(normalize);

  const users = await User.find({
    email: { $in: normalized }
  })
    .select("_id email fullName")
    .lean();

  if (users.length !== normalized.length) {
    const found = new Set(users.map(u => u.email));

    res.status(400).json({
      success: false,
      message: "Email chưa đăng ký",
      missingEmails: normalized.filter(e => !found.has(e))
    });
    return null;
  }

  return users;
}

async function details(req, res) {
  try {
    const task = req.task;

    const ids = [
      ...new Set([
        String(task.createdBy),
        ...task.assigneeIds.map(String),
        ...(task.primaryAssigneeId
          ? [String(task.primaryAssigneeId)]
          : []),
        ...task.shares.map(s => String(s.userId))
      ])
    ];

    const users = await User.find({
      _id: { $in: ids }
    })
      .select("_id fullName email")
      .lean();

    const user = id =>
      users.find(u => eq(u._id, id)) || null;

    res.json({
      success: true,
      role: req.taskRole,
      owner: user(task.createdBy),
      primaryAssignee: task.primaryAssigneeId
        ? user(task.primaryAssigneeId)
        : null,
      assignees: task.assigneeIds.map(user).filter(Boolean),
      shares: task.shares
        .map(s => ({
          user: user(s.userId),
          role: s.role
        }))
        .filter(s => s.user)
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: "Không thể tải thành viên"
    });
  }
}

async function primary(req, res) {
  try {
    const email = normalize(req.body?.email);

    if (!pattern.test(email)) {
      return res.status(400).json({
        success: false,
        message: "Email không hợp lệ"
      });
    }

    const user = await User.findOne({ email })
      .select("_id email fullName");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Tài khoản không tồn tại"
      });
    }

    if (eq(user._id, req.task.createdBy)) {
      return res.status(400).json({
        success: false,
        message: "Không thể chọn người tạo làm người phụ trách"
      });
    }

    if (
      !req.task.assigneeIds.some(id => eq(id, user._id))
    ) {
      return res.status(400).json({
        success: false,
        message: "Hãy giao việc cho người này trước"
      });
    }

    req.task.primaryAssigneeId = user._id;
    await req.task.save();

    res.json({
      success: true,
      message: "Đã chọn người phụ trách chính",
      primaryAssignee: user
    });
  } catch (err) {
    console.error(err);
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: "Không thể chọn người phụ trách"
      });
    }
  }
}

async function removeAssignee(req, res) {
  try {
    const id = req.params.userId;
    const before = req.task.assigneeIds.length;

    req.task.assigneeIds =
      req.task.assigneeIds.filter(x => !eq(x, id));

    if (before === req.task.assigneeIds.length) {
      return res.status(404).json({
        success: false,
        message: "Người này chưa được giao việc"
      });
    }

    if (eq(req.task.primaryAssigneeId, id)) {
      req.task.primaryAssigneeId = null;
    }

    await req.task.save();

    res.json({
      success: true,
      message: "Đã thu hồi giao việc"
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: "Không thể thu hồi giao việc"
    });
  }
}

// ======================================================
// D2. CHIA SE CONG VIEC VA TAO THONG BAO
// D7. GUI EMAIL KHI CHIA SE MOI
// ======================================================

async function upsertShares(req, res) {
  try {
    const { emails, role } = req.body || {};

    if (!["viewer", "editor"].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Quyền phải là viewer hoặc editor"
      });
    }

    const users = await resolveUsers(emails, res);
    if (!users) return;

    if (users.some(u => eq(u._id, req.task.createdBy))) {
      return res.status(400).json({
        success: false,
        message: "Không thể chia sẻ cho người tạo"
      });
    }

    // D2: Chi thong bao cho nguoi moi duoc chia se.
    const newRecipientIds = [];

    for (const u of users) {
      const found = req.task.shares.find(
        s => eq(s.userId, u._id)
      );

      if (found) {
        // Cap nhat quyen cua nguoi da duoc chia se.
        found.role = role;
      } else {
        // Them nguoi moi vao danh sach chia se.
        req.task.shares.push({
          userId: u._id,
          role
        });

        newRecipientIds.push(u._id);
      }
    }

    // Luu chia se thanh cong truoc khi tao thong bao.
    await req.task.save();

    let notificationResult = {
      success: true,
      created: 0
    };

    if (newRecipientIds.length > 0) {
      notificationResult = await notifyTaskShared({
        taskId: req.task._id,
        taskTitle: req.task.title,
        actorId: req.user._id,
        recipientIds: newRecipientIds
      });

      if (!notificationResult.success) {
        console.error(
          "D2 notification warning:",
          notificationResult.message
        );
      }
    }

    // ==================================================
    // D7. GUI EMAIL CHO NGUOI MOI DUOC CHIA SE
    // ==================================================

    let emailResult = {
      success: true,
      attempted: 0,
      sent: 0,
      failed: 0
    };

    if (newRecipientIds.length > 0) {
      try {
        emailResult = await sendTaskEventEmails({
          eventType: "task_shared",
          taskTitle: req.task.title,
          actorId: req.user._id,
          recipientIds: newRecipientIds,
          role
        });

        if (!emailResult.success) {
          console.error(
            "D7 share email warning: Some emails were not sent"
          );
        }
      } catch (emailError) {
        console.error(
          "D7 share email error:",
          emailError.code || "SERVICE_ERROR"
        );

        emailResult = {
          success: false,
          attempted: 0,
          sent: 0,
          failed: 1
        };
      }
    }

    return res.json({
      success: true,
      message: "Đã cấp hoặc cập nhật quyền chia sẻ",
      total: req.task.shares.length,
      notification: {
        success: notificationResult.success,
        created: notificationResult.created
      },
      emailNotification: {
        success: emailResult.success,
        attempted: emailResult.attempted,
        sent: emailResult.sent,
        failed: emailResult.failed
      }
    });
  } catch (err) {
    console.error(err);

    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: "Không thể chia sẻ công việc"
      });
    }
  }
}

async function removeShare(req, res) {
  try {
    const id = req.params.userId;
    const before = req.task.shares.length;

    req.task.shares = req.task.shares.filter(
      s => !eq(s.userId, id)
    );

    if (before === req.task.shares.length) {
      return res.status(404).json({
        success: false,
        message: "Chưa chia sẻ cho tài khoản này"
      });
    }

    await req.task.save();

    res.json({
      success: true,
      message: "Đã thu hồi quyền chia sẻ"
    });
  } catch (err) {
    console.error(err);

    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: "Không thể thu hồi quyền"
      });
    }
  }
}

module.exports = {
  details,
  primary,
  removeAssignee,
  upsertShares,
  removeShare
};
