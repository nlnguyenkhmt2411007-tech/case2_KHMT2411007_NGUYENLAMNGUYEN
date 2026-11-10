
const Notification = require("../models/Notification");

// ======================================================
// D1. THONG BAO KHI DUOC GIAO CONG VIEC
// ======================================================

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

// ======================================================
// D2. THONG BAO KHI CONG VIEC DUOC CHIA SE
// ======================================================

async function notifyTaskShared({
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
      message: "Thieu thong tin tao thong bao chia se"
    };
  }

  const uniqueIds = [
    ...new Set(recipientIds.map((id) => String(id)))
  ];

  const notifications = uniqueIds.map((recipientId) => ({
    recipientId,
    actorId,
    taskId,
    type: "task_shared",
    title: "Ban duoc chia se cong viec",
    message: `Ban duoc chia se cong viec: ${taskTitle}`,
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
      "Create share notifications error:",
      error.message
    );

    return {
      success: false,
      created: 0,
      message: "Khong the luu thong bao chia se"
    };
  }
}

// ======================================================
// D3. THONG BAO KHI TRANG THAI CONG VIEC THAY DOI
// ======================================================

const STATUS_LABELS = {
  chua_thuc_hien: "Chưa thực hiện",
  dang_thuc_hien: "Đang thực hiện",
  da_hoan_thanh: "Đã hoàn thành"
};

async function notifyTaskStatusChanged({
  taskId,
  taskTitle,
  actorId,
  recipientIds,
  oldStatus,
  newStatus
}) {
  // 1. Kiem tra du lieu dau vao.
  if (
    !taskId ||
    !actorId ||
    !Array.isArray(recipientIds) ||
    !STATUS_LABELS[oldStatus] ||
    !STATUS_LABELS[newStatus]
  ) {
    return {
      success: false,
      created: 0,
      message: "Thieu hoac sai thong tin thong bao D3"
    };
  }

  // 2. Trang thai khong thay doi thi khong thong bao.
  if (oldStatus === newStatus) {
    return {
      success: true,
      created: 0
    };
  }

  // 3. Loai bo ID trung, rong va nguoi vua cap nhat.
  const actor = String(actorId);

  const uniqueIds = [
    ...new Set(
      recipientIds
        .filter(Boolean)
        .map((id) => String(id))
    )
  ].filter((id) => id !== actor);

  // 4. Khong co nguoi nhan.
  if (uniqueIds.length === 0) {
    return {
      success: true,
      created: 0
    };
  }

  // 5. Tao noi dung thong bao.
  const oldLabel = STATUS_LABELS[oldStatus];
  const newLabel = STATUS_LABELS[newStatus];

  const notifications = uniqueIds.map((recipientId) => ({
    recipientId,
    actorId,
    taskId,
    type: "task_status_changed",
    title: "Trạng thái công việc đã thay đổi",
    message:
      `Công việc "${taskTitle}" đã chuyển ` +
      `từ "${oldLabel}" sang "${newLabel}".`,
    isRead: false
  }));

  // 6. Luu thong bao vao MongoDB.
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
      "Create status change notifications error:",
      error.message
    );

    return {
      success: false,
      created: 0,
      message: "Khong the luu thong bao thay doi trang thai"
    };
  }
}

module.exports = {
  notifyTaskAssigned,
  notifyTaskShared,
  notifyTaskStatusChanged
};
