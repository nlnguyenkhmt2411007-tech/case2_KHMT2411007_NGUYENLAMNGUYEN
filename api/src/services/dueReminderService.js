
const nodemailer = require("nodemailer");

const Task = require("../models/Task");
const User = require("../models/User");
const Notification = require("../models/Notification");
const DueReminder = require("../models/DueReminder");
const EmailLog = require("../models/EmailLog");

// ======================================================
// D5. NHAC VIEC TRUOC HAN - THEO DE BAI
// ======================================================

// Giu tuong thich voi model va scheduler D8 cu.
const HOURS_BEFORE = 24;
const IN_APP_RECOVERY_MINUTES = 10;

let scanRunning = false;

// ======================================================
// D6. LUU LICH SU GUI EMAIL NHAC HAN
// ======================================================

async function saveReminderEmailLog({
  task,
  recipient,
  attemptedAt,
  status,
  errorCode,
  messageId
}) {
  try {
    await EmailLog.create({
      eventType: "task_due_reminder",
      taskId: task._id,
      actorId: null,
      recipientId: recipient._id,
      recipientEmail: recipient.email,
      subject: "TaskManager - Nhắc nhở công việc sắp đến hạn",
      status,
      attemptedAt,
      sentAt: status === "sent" ? new Date() : null,
      errorCode: status === "failed"
        ? String(errorCode || "EMAIL_FAILED").slice(0, 100)
        : null,
      messageId: messageId ? String(messageId).slice(0, 255) : null
    });
  } catch (error) {
    // Khong gui lai SMTP neu ghi log that bai.
    console.error(
      "D6 reminder email log failed:",
      error.code || "EMAIL_LOG_FAILED"
    );
  }
}

function uniqueRecipientIds(task) {
  const ids = [
    task.createdBy,
    task.primaryAssigneeId,
    ...(task.assigneeIds || []),
    ...(task.shares || []).map(
      (share) => share.userId
    )
  ];

  return [
    ...new Set(
      ids.filter(Boolean).map(String)
    )
  ];
}

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
    throw new Error("SMTP_CONFIG_INVALID");
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
// KIEM TRA INDEX CHONG TRUNG
// ======================================================

async function verifyIndexes() {
  await Notification.init();
  await DueReminder.init();

  const notificationIndexes =
    await Notification.collection.indexes();

  const reminderIndexes =
    await DueReminder.collection.indexes();

  const hasNotificationIndex =
    notificationIndexes.some(
      (index) =>
        index.name ===
          "unique_due_reminder_notification" &&
        index.unique === true &&
        index.key?.reminderId === 1 &&
        index.partialFilterExpression
          ?.reminderId?.$type === "objectId"
    );

  const hasReminderIndex =
    reminderIndexes.some(
      (index) =>
        index.name === "unique_due_reminder" &&
        index.unique === true &&
        index.key?.taskId === 1 &&
        index.key?.recipientId === 1 &&
        index.key?.dueDate === 1 &&
        index.key?.hoursBefore === 1
    );

  if (!hasNotificationIndex ||
      !hasReminderIndex) {
    throw new Error(
      "D5_UNIQUE_INDEX_MISSING"
    );
  }
}

// ======================================================
// KIEM TRA CONG VIEC CON CAN NHAC HAY KHONG
// ======================================================

async function isTaskEligible(taskId, dueDate) {
  const now = new Date();
  const until = new Date(
    now.getTime() +
    HOURS_BEFORE * 60 * 60 * 1000
  );

  return Task.exists({
    _id: taskId,
    status: {
      $ne: "da_hoan_thanh"
    },
    dueDate: dueDate,
    $and: [
      { dueDate: { $gt: now } },
      { dueDate: { $lte: until } }
    ]
  });
}

// ======================================================
// TAO BAN GHI NHAC HAN DUY NHAT
// ======================================================

async function ensureReminder(task, recipientId) {
  const key = {
    taskId: task._id,
    recipientId,
    dueDate: task.dueDate,
    hoursBefore: HOURS_BEFORE
  };

  try {
    await DueReminder.updateOne(
      key,
      {
        $setOnInsert: key
      },
      {
        upsert: true
      }
    );
  } catch (error) {
    if (error.code !== 11000) {
      throw error;
    }
  }

  return key;
}

// ======================================================
// PHUC HOI THONG BAO TRONG UNG DUNG
// ======================================================

async function recoverInAppReminder(key) {
  const staleBefore = new Date(
    Date.now() -
    IN_APP_RECOVERY_MINUTES * 60 * 1000
  );

  const reminder = await DueReminder.findOne(key);

  if (
    !reminder ||
    reminder.inAppStatus !== "processing" ||
    reminder.updatedAt > staleBefore
  ) {
    return;
  }

  // Neu thong bao da ton tai thi khong tao lai.
  const existing = await Notification.exists({
    reminderId: reminder._id
  });

  if (existing) {
    await DueReminder.updateOne(
      {
        _id: reminder._id,
        inAppStatus: "processing",
        updatedAt: { $lte: staleBefore }
      },
      {
        $set: {
          inAppStatus: "sent",
          inAppSentAt: new Date()
        }
      }
    );
  } else {
    // Unique index bao ve neu lan thu lai
    // va lan xu ly cu cung tao thong bao.
    await DueReminder.updateOne(
      {
        _id: reminder._id,
        inAppStatus: "processing",
        updatedAt: { $lte: staleBefore }
      },
      {
        $set: {
          inAppStatus: "pending"
        }
      }
    );
  }
}

// ======================================================
// TAO THONG BAO TRONG UNG DUNG
// ======================================================

async function processInAppReminder(
  key,
  task,
  result
) {
  await recoverInAppReminder(key);

  const reminder = await DueReminder.findOneAndUpdate(
    {
      ...key,
      inAppStatus: {
        $in: ["pending", "failed"]
      }
    },
    {
      $set: {
        inAppStatus: "processing"
      }
    },
    {
      returnDocument: "after"
    }
  );

  if (!reminder) {
    return;
  }

  try {
    const eligible = await isTaskEligible(
      task._id,
      task.dueDate
    );

    if (!eligible) {
      await DueReminder.updateOne(
        { _id: reminder._id },
        {
          $set: {
            inAppStatus: "pending"
          }
        }
      );

      return;
    }

    const existing = await Notification.exists({
      reminderId: reminder._id
    });

    if (!existing) {
      try {
        await Notification.create({
          reminderId: reminder._id,
          recipientId: key.recipientId,
          actorId: null,
          taskId: task._id,
          type: "task_due_reminder",
          title: "Công việc sắp đến hạn",
          message:
            `Công việc "${task.title}" ` +
            "sắp đến hạn. Vui lòng kiểm tra tiến độ.",
          isRead: false
        });

        result.inAppCreated++;
      } catch (error) {
        // Neu ban ghi duoc tao boi luot
        // xu ly khac, coi nhu da ton tai.
        if (error.code !== 11000) {
          throw error;
        }
      }
    }

    await DueReminder.updateOne(
      {
        _id: reminder._id,
        inAppStatus: "processing"
      },
      {
        $set: {
          inAppStatus: "sent",
          inAppSentAt: new Date()
        }
      }
    );
  } catch (error) {
    await DueReminder.updateOne(
      {
        _id: reminder._id,
        inAppStatus: "processing"
      },
      {
        $set: {
          inAppStatus: "failed"
        }
      }
    );

    result.inAppFailed++;

    console.error(
      "D5 in-app reminder error:",
      error.code || "IN_APP_FAILED"
    );
  }
}

// ======================================================
// GUI EMAIL NHAC HAN
// ======================================================

async function processEmailReminder(
  key,
  task,
  result,
  transporterHolder
) {
  // Chi gui cho ban ghi pending.
  // failed va processing khong tu dong gui lai.
  const reminder = await DueReminder.findOneAndUpdate(
    {
      ...key,
      emailStatus: "pending"
    },
    {
      $set: {
        emailStatus: "processing",
        lastAttemptAt: new Date()
      },
      $inc: {
        emailAttempts: 1
      }
    },
    {
      returnDocument: "after"
    }
  );

  if (!reminder) {
    return;
  }

  let recipient = null;
  let smtpAttempted = false;
  let smtpAccepted = false;
  let smtpAttemptedAt = null;
  let smtpMessageId = null;
  let smtpErrorCode = null;

  try {
    const eligible = await isTaskEligible(
      task._id,
      task.dueDate
    );

    if (!eligible) {
      // Chua gui SMTP: co the giu pending.
      await DueReminder.updateOne(
        {
          _id: reminder._id,
          emailStatus: "processing"
        },
        {
          $set: {
            emailStatus: "pending"
          }
        }
      );

      return;
    }

    recipient = await User.findById(
      key.recipientId
    )
      .select("fullName email")
      .lean();

    if (!recipient?.email) {
      throw new Error("RECIPIENT_NOT_FOUND");
    }

    if (!transporterHolder.current) {
      transporterHolder.current =
        createTransporter();
    }

    result.emailAttempted++;
    smtpAttempted = true;
    smtpAttemptedAt = new Date();

    const response =
      await transporterHolder.current.sendMail({
        from: process.env.EMAIL_FROM,
        to: recipient.email,
        subject:
          "TaskManager - Nhắc nhở công việc sắp đến hạn",
        text:
          `Xin chào ${recipient.fullName || "bạn"},\n\n` +
          `Công việc "${task.title}" sắp đến hạn.\n` +
          `Hạn trên hệ thống (UTC): ` +
          `${task.dueDate.toISOString().slice(0, 10)}\n\n` +
          `Vui lòng đăng nhập TaskManager để ` +
          `kiểm tra tiến độ.\n\n` +
          `Trân trọng,\nTaskManager`
      });

    if (!response.accepted?.length) {
      throw new Error("SMTP_NOT_ACCEPTED");
    }

    // Ghi nhan SMTP da chap nhan, truoc khi cap nhat MongoDB.
    smtpAccepted = true;
    smtpMessageId = response.messageId || null;

    await DueReminder.updateOne(
      {
        _id: reminder._id,
        emailStatus: "processing"
      },
      {
        $set: {
          emailStatus: "sent",
          emailSentAt: new Date(),
          lastError: null
        }
      }
    );

    result.emailSent++;
  } catch (error) {
    const code = String(
      error.code || error.message || "EMAIL_FAILED"
    ).slice(0, 100);
    smtpErrorCode = code;

    // Khong tu dong retry:
    // SMTP co the da nhan email truoc khi loi.
    await DueReminder.updateOne(
      {
        _id: reminder._id,
        emailStatus: "processing"
      },
      {
        $set: {
          emailStatus: "failed",
          lastError: code
        }
      }
    );

    result.emailFailed++;

    console.error(
      "D5 email reminder error:",
      code
    );
  } finally {
    // D6 chi ghi 1 log neu da bat dau thu gui SMTP.
    // Neu SMTP da chap nhan nhung cap nhat DB bi loi,
    // van ghi "sent", khong lam sai ket qua giao thu.
    if (smtpAttempted && recipient?.email) {
      await saveReminderEmailLog({
        task,
        recipient,
        attemptedAt: smtpAttemptedAt,
        status: smtpAccepted ? "sent" : "failed",
        errorCode: smtpAccepted ? null : smtpErrorCode,
        messageId: smtpMessageId
      });
    }
  }
}

// ======================================================
// QUET CONG VIEC SAP DEN HAN
// ======================================================

async function runDueReminderCheck() {
  const result = {
    success: true,
    tasksFound: 0,
    recipientsChecked: 0,
    inAppCreated: 0,
    inAppFailed: 0,
    emailAttempted: 0,
    emailSent: 0,
    emailFailed: 0
  };

  // Khong cho quet trung trong cung process.
  if (scanRunning) {
    return {
      ...result,
      success: false,
      skipped: true
    };
  }

  scanRunning = true;

  const transporterHolder = {
    current: null
  };

  try {
    // D5 TEST MODE: chi cho phep 1 task + 1 recipient + 1 email.
    // Mac dinh tat, khong anh huong che do chay chinh thuc.
    const testMode =
      process.env.D5_TEST_MODE === "true";

    const testTaskId =
      String(process.env.D5_TEST_TASK_ID || "").trim();

    const testRecipientId =
      String(process.env.D5_TEST_RECIPIENT_ID || "").trim();

    const testEmail =
      String(process.env.D5_TEST_EMAIL || "").trim().toLowerCase();

    if (testMode) {
      if (
        !/^[0-9a-fA-F]{24}$/.test(testTaskId) ||
        !/^[0-9a-fA-F]{24}$/.test(testRecipientId) ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(testEmail)
      ) {
        throw new Error("D5_TEST_CONFIG_INVALID");
      }

      const testRecipient = await User.findById(
        testRecipientId
      ).select("email").lean();

      if (
        String(testRecipient?.email || "").trim().toLowerCase() !==
        testEmail
      ) {
        throw new Error("D5_TEST_RECIPIENT_EMAIL_MISMATCH");
      }

      console.log(
        "D5 TEST MODE: chi xu ly mot task va mot recipient"
      );
    }

    // Bat buoc co unique index truoc khi gui.
    await verifyIndexes();

    const now = new Date();
    const until = new Date(
      now.getTime() +
      HOURS_BEFORE * 60 * 60 * 1000
    );

    const taskFilter = {
      status: {
        $ne: "da_hoan_thanh"
      },
      dueDate: {
        $gt: now,
        $lte: until
      }
    };

    if (testMode) {
      taskFilter._id = testTaskId;
    }

    const tasks = await Task.find(taskFilter).lean();

    result.tasksFound = tasks.length;

    for (const task of tasks) {
      let recipientIds =
        uniqueRecipientIds(task);

      if (testMode) {
        recipientIds = recipientIds.filter(
          (id) => String(id) === testRecipientId
        );
      }

      for (const recipientId of recipientIds) {
        result.recipientsChecked++;

        try {
          const key = await ensureReminder(
            task,
            recipientId
          );

          await processInAppReminder(
            key,
            task,
            result
          );

          await processEmailReminder(
            key,
            task,
            result,
            transporterHolder
          );
        } catch (error) {
          result.success = false;

          console.error(
            "D5 reminder processing error:",
            error.code || "PROCESSING_FAILED"
          );
        }
      }
    }

    result.success =
      result.success &&
      result.inAppFailed === 0 &&
      result.emailFailed === 0;

    return result;
  } catch (error) {
    console.error(
      "D5 reminder scan error:",
      error.code || error.message
    );

    return {
      ...result,
      success: false
    };
  } finally {
    if (transporterHolder.current) {
      transporterHolder.current.close();
    }

    scanRunning = false;
  }
}

module.exports = {
  runDueReminderCheck
};
