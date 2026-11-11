
const nodemailer = require("nodemailer");
const User = require("../models/User");

// ======================================================
// D7. GUI EMAIL THONG BAO CONG VIEC
// ======================================================

const STATUS_LABELS = {
  chua_thuc_hien: "Chưa thực hiện",
  dang_thuc_hien: "Đang thực hiện",
  da_hoan_thanh: "Đã hoàn thành"
};

function createTransporter() {
  const port = Number(process.env.SMTP_PORT);

  if (
    !process.env.SMTP_HOST ||
    !process.env.SMTP_USER ||
    !process.env.SMTP_PASS ||
    !process.env.EMAIL_FROM ||
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535
  ) {
    throw new Error("Cau hinh SMTP khong hop le");
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    },
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000
  });
}

function buildEmailContent({
  eventType,
  taskTitle,
  actorName,
  oldStatus,
  newStatus,
  role
}) {
  const title = String(taskTitle || "Công việc").trim();
  const actor = String(actorName || "Một thành viên").trim();

  switch (eventType) {
    case "task_assigned":
      return {
        subject: "TaskManager - Bạn được giao công việc mới",
        text:
          `Xin chào,\n\n` +
          `${actor} đã giao cho bạn công việc:\n` +
          `${title}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    case "task_shared":
      return {
        subject: "TaskManager - Bạn được chia sẻ công việc",
        text:
          `Xin chào,\n\n` +
          `${actor} đã chia sẻ với bạn công việc:\n` +
          `${title}\n\n` +
          `Quyền truy cập: ${role === "editor" ? "Chỉnh sửa" : "Chỉ xem"}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    case "task_status_changed":
      return {
        subject: "TaskManager - Trạng thái công việc thay đổi",
        text:
          `Xin chào,\n\n` +
          `${actor} đã cập nhật trạng thái công việc:\n` +
          `${title}\n\n` +
          `Trạng thái cũ: ${STATUS_LABELS[oldStatus]}\n` +
          `Trạng thái mới: ${STATUS_LABELS[newStatus]}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    default:
      throw new Error("Loai su kien email khong hop le");
  }
}

async function sendTaskEventEmails({
  eventType,
  taskTitle,
  actorId,
  recipientIds,
  oldStatus,
  newStatus,
  role
}) {
  const result = {
    success: true,
    attempted: 0,
    sent: 0,
    failed: 0
  };

  try {
    if (
      !actorId ||
      !Array.isArray(recipientIds) ||
      ![
        "task_assigned",
        "task_shared",
        "task_status_changed"
      ].includes(eventType)
    ) {
      throw new Error("Du lieu su kien email khong hop le");
    }

    if (
      eventType === "task_status_changed" &&
      (
        !STATUS_LABELS[oldStatus] ||
        !STATUS_LABELS[newStatus]
      )
    ) {
      throw new Error("Trang thai khong hop le");
    }

    // Khong gui email neu trang thai khong thay doi.
    if (
      eventType === "task_status_changed" &&
      oldStatus === newStatus
    ) {
      return result;
    }

    // Loai ID trung va nguoi thuc hien thao tac.
    const ids = [
      ...new Set(
        recipientIds
          .filter(Boolean)
          .map((id) => String(id))
      )
    ].filter((id) => id !== String(actorId));

    if (ids.length === 0) {
      return result;
    }

    // Lay thong tin nguoi nhan tu MongoDB.
    const recipients = await User.find({
      _id: { $in: ids }
    })
      .select("_id fullName email")
      .lean();

    const actor = await User.findById(actorId)
      .select("fullName")
      .lean();

    const content = buildEmailContent({
      eventType,
      taskTitle,
      actorName: actor?.fullName,
      oldStatus,
      newStatus,
      role
    });

    const transporter = createTransporter();

    // Gui rieng tung nguoi, khong lo danh sach email.
    for (const recipient of recipients) {
      result.attempted++;

      try {
        const response = await transporter.sendMail({
          from: process.env.EMAIL_FROM,
          to: recipient.email,
          subject: content.subject,
          text:
            `Gửi đến: ${recipient.fullName || "Thành viên"}\n\n` +
            content.text
        });

        if (response.accepted?.length > 0) {
          result.sent++;
        } else {
          result.failed++;
        }
      } catch (error) {
        result.failed++;

        // Khong in dia chi email hoac thong tin xac thuc.
        console.error(
          "D7 email delivery failed:",
          error.code || "UNKNOWN"
        );
      }
    }

    result.success = result.failed === 0;

    return result;
  } catch (error) {
    console.error(
      "D7 email service error:",
      error.code || "SERVICE_ERROR"
    );

    return {
      ...result,
      success: false,
      failed: Math.max(1, result.failed)
    };
  }
}

module.exports = {
  sendTaskEventEmails
};
