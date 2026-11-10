
const Notification = require("../models/Notification");

// Tao thong bao khi giao cong viec.
// Chi goi ham nay sau khi viec giao cong viec da luu thanh cong.
async function notifyTaskAssigned({
  taskId,
  taskTitle,
  actorId,
  recipientIds
}) {
  if (
    !taskId ||
    !actorId ||
    !Array.isArray(recipientIds) ||
    recipientIds.length === 0
  ) {
    return {
      success: false,
      created: 0,
      message: "Thieu thong tin tao thong bao"
    };
  }

  const uniqueIds = [
    ...new Set(recipientIds.map((id) => String(id)))
  ];

  const notifications = uniqueIds.map((recipientId) => ({
    recipientId,
    actorId,
    taskId,
    type: "task_assigned",
    title: "Ban duoc giao cong viec moi",
    message: `Ban duoc giao cong viec: ${taskTitle}`,
    isRead: false
  }));

  try {
    const result = await Notification.insertMany(
      notifications,
      { ordered: true }
    );

    return {
      success: true,
      created: result.length
    };
  } catch (error) {
    console.error(
      "Create assignment notifications error:",
      error.message
    );

    return {
      success: false,
      created: 0,
      message: "Khong the luu thong bao giao viec"
    };
  }
}

module.exports = {
  notifyTaskAssigned
};
