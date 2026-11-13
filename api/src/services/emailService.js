
const nodemailer = require("nodemailer");

const User = require("../models/User");
const EmailLog = require("../models/EmailLog");

// ======================================================
// D3 + D6. GUI EMAIL VA LUU LICH SU
// ======================================================

const STATUS_LABELS = {
  chua_thuc_hien: "Chưa thực hiện",
  dang_thuc_hien: "Đang thực hiện",
  da_hoan_thanh: "Đã hoàn thành"
};

// ======================================================
// CAU HINH SMTP
// ======================================================

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

// ======================================================
// D3. DINH DANG NGAY HOAN THANH
// ======================================================

function normalizeDueDate(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    throw new Error("Ngay hoan thanh khong hop le");
  }

  // Su dung UTC de phu hop voi ngay duoc luu trong MongoDB.
  return date.toISOString().slice(0, 10);
}

function formatDueDate(value) {
  const normalized = normalizeDueDate(value);

  if (!normalized) {
    return "Chưa đặt hạn";
  }

  const [year, month, day] = normalized.split("-");

  return `${day}/${month}/${year}`;
}

// ======================================================
// NOI DUNG EMAIL
// ======================================================

function buildEmailContent({
  eventType,
  taskTitle,
  actorName,
  oldStatus,
  newStatus,
  oldDueDate,
  newDueDate,
  role
}) {
  const title = String(
    taskTitle || "Công việc"
  ).trim();

  const actor = String(
    actorName || "Một thành viên"
  ).trim();

  switch (eventType) {
    case "task_assigned":
      return {
        subject:
          "TaskManager - Bạn được giao công việc mới",
        text:
          `Xin chào,\n\n` +
          `${actor} đã giao cho bạn công việc:\n` +
          `${title}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    case "task_shared":
      return {
        subject:
          "TaskManager - Bạn được chia sẻ công việc",
        text:
          `Xin chào,\n\n` +
          `${actor} đã chia sẻ với bạn công việc:\n` +
          `${title}\n\n` +
          `Quyền truy cập: ${
            role === "editor"
              ? "Chỉnh sửa"
              : "Chỉ xem"
          }\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    case "task_status_changed":
      return {
        subject:
          "TaskManager - Trạng thái công việc thay đổi",
        text:
          `Xin chào,\n\n` +
          `${actor} đã cập nhật trạng thái công việc:\n` +
          `${title}\n\n` +
          `Trạng thái cũ: ${STATUS_LABELS[oldStatus]}\n` +
          `Trạng thái mới: ${STATUS_LABELS[newStatus]}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    // D3: Email khi thay doi han hoan thanh.
    case "task_due_date_changed":
      return {
        subject:
          "TaskManager - Hạn hoàn thành công việc thay đổi",
        text:
          `Xin chào,\n\n` +
          `${actor} đã thay đổi hạn hoàn thành của công việc:\n` +
          `${title}\n\n` +
          `Hạn cũ: ${formatDueDate(oldDueDate)}\n` +
          `Hạn mới: ${formatDueDate(newDueDate)}\n\n` +
          `Vui lòng đăng nhập TaskManager để xem chi tiết.\n\n` +
          `Trân trọng,\nTaskManager`
      };

    default:
      throw new Error(
        "Loai su kien email khong hop le"
      );
  }
}

// ======================================================
// D6. GHI LICH SU GUI EMAIL VAO MONGODB
// ======================================================

async function saveEmailLog({
  eventType,
  taskId,
  actorId,
  recipientId,
  recipientEmail,
  subject,
  status,
  errorCode,
  messageId
}) {
  try {
    await EmailLog.create({
      eventType,

      taskId: taskId || null,

      actorId: actorId || null,

      recipientId: recipientId || null,

      recipientEmail: String(
        recipientEmail || ""
      ).trim().toLowerCase(),

      subject,

      status,

      attemptedAt: new Date(),

      sentAt:
        status === "sent"
          ? new Date()
          : null,

      errorCode:
        status === "failed"
          ? String(
              errorCode || "EMAIL_FAILED"
            ).slice(0, 100)
          : null,

      messageId:
        messageId
          ? String(messageId).slice(0, 255)
          : null
    });

    return true;
  } catch (error) {
    console.error(
      "D6 email log save failed:",
      error.code || error.message
    );

    return false;
  }
}

// ======================================================
// GUI EMAIL THEO SU KIEN CONG VIEC
// ======================================================

async function sendTaskEventEmails({
  eventType,
  taskId,
  taskTitle,
  actorId,
  recipientIds,
  oldStatus,
  newStatus,
  oldDueDate,
  newDueDate,
  role
}) {
  const result = {
    success: true,
    attempted: 0,
    sent: 0,
    failed: 0
  };

  let transporter = null;

  try {
    if (
      !actorId ||
      !Array.isArray(recipientIds) ||
      ![
        "task_assigned",
        "task_shared",
        "task_status_changed",
        "task_due_date_changed"
      ].includes(eventType)
    ) {
      throw new Error(
        "Du lieu su kien email khong hop le"
      );
    }

    if (
      eventType === "task_status_changed" &&
      (
        !STATUS_LABELS[oldStatus] ||
        !STATUS_LABELS[newStatus]
      )
    ) {
      throw new Error(
        "Trang thai khong hop le"
      );
    }

    // Khong gui neu trang thai khong thay doi.
    if (
      eventType === "task_status_changed" &&
      oldStatus === newStatus
    ) {
      return result;
    }

    // D3: Khong gui neu han hoan thanh khong thay doi.
    if (eventType === "task_due_date_changed") {
      const oldDate = normalizeDueDate(oldDueDate);
      const newDate = normalizeDueDate(newDueDate);

      if (oldDate === newDate) {
        return result;
      }
    }

    // Loai bo ID trung va nguoi thuc hien thao tac.
    const ids = [
      ...new Set(
        recipientIds
          .filter(Boolean)
          .map((id) => String(id))
      )
    ].filter(
      (id) => id !== String(actorId)
    );

    if (ids.length === 0) {
      return result;
    }

    // Lay danh sach nguoi nhan.
    const recipients = await User.find({
      _id: {
        $in: ids
      }
    })
      .select("_id fullName email")
      .lean();

    // Lay thong tin nguoi thuc hien.
    const actor = await User.findById(
      actorId
    )
      .select("fullName")
      .lean();

    const content = buildEmailContent({
      eventType,
      taskTitle,
      actorName: actor?.fullName,
      oldStatus,
      newStatus,
      oldDueDate,
      newDueDate,
      role
    });

    // Giu nguyen cau hinh SMTP hien tai.
    transporter = createTransporter();

    // Gui rieng tung nguoi.
    for (const recipient of recipients) {
      result.attempted++;

      const email = String(
        recipient.email || ""
      ).trim().toLowerCase();

      let emailStatus = "failed";
      let emailError = null;
      let messageId = null;

      try {
        if (!email) {
          throw new Error(
            "RECIPIENT_EMAIL_MISSING"
          );
        }

        const response =
          await transporter.sendMail({
            from: process.env.EMAIL_FROM,
            to: email,
            subject: content.subject,
            text:
              `Gửi đến: ${
                recipient.fullName || "Thành viên"
              }\n\n` +
              content.text
          });

        messageId =
          response.messageId || null;

        // SMTP chap nhan email.
        if (
          Array.isArray(response.accepted) &&
          response.accepted.length > 0
        ) {
          emailStatus = "sent";
          result.sent++;
        } else {
          emailStatus = "failed";
          emailError = "SMTP_NOT_ACCEPTED";
          result.failed++;
        }
      } catch (error) {
        emailStatus = "failed";
        emailError = String(
          error.code ||
          error.message ||
          "EMAIL_FAILED"
        ).slice(0, 100);

        result.failed++;

        console.error(
          "D6 email delivery failed:",
          error.code || "UNKNOWN"
        );
      }

      // D6: Luu lich su sau moi lan thu gui.
      await saveEmailLog({
        eventType,
        taskId,
        actorId,
        recipientId: recipient._id,
        recipientEmail: email,
        subject: content.subject,
        status: emailStatus,
        errorCode: emailError,
        messageId
      });
    }

    result.success =
      result.failed === 0;

    return result;
  } catch (error) {
    console.error(
      "D6 email service error:",
      error.code || "SERVICE_ERROR"
    );

    return {
      ...result,
      success: false,
      failed: Math.max(
        1,
        result.failed
      )
    };
  } finally {
    if (transporter) {
      transporter.close();
    }
  }
}

// ======================================================
// EXPORT
// ======================================================

module.exports = {
  sendTaskEventEmails
};
