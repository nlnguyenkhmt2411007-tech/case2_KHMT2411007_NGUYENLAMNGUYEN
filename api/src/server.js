
require("dotenv").config({ quiet: true });

const app = require("./app");
const connectDatabase = require("./config/database");
const {
  runDueReminderCheck
} = require("./services/dueReminderService");

const PORT = process.env.PORT || 3000;

// D8: Kiem tra moi 5 phut.
// Mac dinh tat cho den khi kiem thu xong.
const D8_ENABLED =
  process.env.D8_REMINDERS_ENABLED === "true";

const D8_INTERVAL_MS = 5 * 60 * 1000;

let reminderRunning = false;
let reminderTimer = null;

async function checkDueReminders() {
  // Khong cho hai luot quet chay dong thoi
  // trong cung mot tien trinh Backend.
  if (reminderRunning) {
    console.log("D8: Bo qua do luot quet truoc chua xong");
    return;
  }

  reminderRunning = true;

  try {
    const result = await runDueReminderCheck();

    console.log("D8 REMINDER RESULT:", {
      success: result.success,
      tasksFound: result.tasksFound,
      recipientsChecked: result.recipientsChecked,
      inAppCreated: result.inAppCreated,
      inAppFailed: result.inAppFailed,
      emailAttempted: result.emailAttempted,
      emailSent: result.emailSent,
      emailFailed: result.emailFailed
    });
  } catch (error) {
    console.error(
      "D8 reminder scheduler error:",
      error.code || "UNKNOWN"
    );
  } finally {
    reminderRunning = false;
  }
}

function startReminderScheduler() {
  if (!D8_ENABLED) {
    console.log(
      "D8: Reminder scheduler DISABLED (safe mode)"
    );
    return;
  }

  console.log(
    "D8: Reminder scheduler ENABLED - every 5 minutes"
  );

  // Quet ngay khi Backend khoi dong.
  void checkDueReminders();

  reminderTimer = setInterval(() => {
    void checkDueReminders();
  }, D8_INTERVAL_MS);
}

async function startServer() {
  try {
    // Ket noi MongoDB truoc khi khoi dong API.
    await connectDatabase();

    const server = app.listen(PORT, () => {
      console.log("--------------------------------");
      console.log("Task Manager Backend");
      console.log(`Server: http://localhost:${PORT}`);
      console.log(
        `Health API: http://localhost:${PORT}/api/health`
      );
      console.log("--------------------------------");

      // D8: Chi khoi dong sau khi HTTP server da san sang.
      startReminderScheduler();
    });

    server.on("error", (error) => {
      console.error(
        "Lỗi khởi động HTTP server:",
        error.message
      );

      if (reminderTimer) {
        clearInterval(reminderTimer);
      }

      process.exit(1);
    });
  } catch (error) {
    console.error(
      "Không thể khởi động backend:",
      error.message
    );

    process.exit(1);
  }
}

startServer();
