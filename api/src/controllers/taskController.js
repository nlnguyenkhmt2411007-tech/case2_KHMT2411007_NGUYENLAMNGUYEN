
const {visibleQuery,taskRole,eq}=require("../middleware/taskAccess");
const User=require("../models/User");

const mongoose = require("mongoose");
const Task = require("../models/Task");
const { notifyTaskStatusChanged } = require("../services/notificationService");
const { sendTaskEventEmails } = require("../services/emailService");

// ======================================================
// PHẦN B - QUẢN LÝ CÔNG VIỆC
// ======================================================

const ALLOWED_STATUSES = [
  "chua_thuc_hien",
  "dang_thuc_hien",
  "da_hoan_thanh"
];

const ALLOWED_PRIORITIES = [
  "thap",
  "trung_binh",
  "cao"
];

// Chấp nhận ngày theo định dạng YYYY-MM-DD.
// null: bỏ ngày; undefined: ngày không hợp lệ.
function parseDate(value) {
  if (
    value === undefined ||
    value === null ||
    value === ""
  ) {
    return null;
  }

  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(value)
  ) {
    return undefined;
  }

  const date = new Date(`${value}T00:00:00.000Z`);

  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== value
  ) {
    return undefined;
  }

  return date;
}

function isValidTaskId(id) {
  return (
    typeof id === "string" &&
    /^[0-9a-fA-F]{24}$/.test(id) &&
    mongoose.isObjectIdOrHexString(id)
  );
}

function sendValidationError(res, message) {
  return res.status(400).json({
    success: false,
    message
  });
}

// ======================================================
// B1. TẠO CÔNG VIỆC
// POST /api/tasks
// ======================================================

async function createTask(req, res) {
  try {
    const {
      title,
      description,
      status,
      priority,
      startDate,
      dueDate
    } = req.body || {};

    if (typeof title !== "string") {
      return sendValidationError(
        res,
        "Vui lòng nhập tên công việc"
      );
    }

    const normalizedTitle = title.trim();

    if (
      normalizedTitle.length < 2 ||
      normalizedTitle.length > 200
    ) {
      return sendValidationError(
        res,
        "Tên công việc phải có từ 2 đến 200 ký tự"
      );
    }

    if (
      description !== undefined &&
      typeof description !== "string"
    ) {
      return sendValidationError(
        res,
        "Mô tả công việc không hợp lệ"
      );
    }

    const normalizedDescription =
      typeof description === "string"
        ? description.trim()
        : "";

    if (normalizedDescription.length > 5000) {
      return sendValidationError(
        res,
        "Mô tả không được vượt quá 5000 ký tự"
      );
    }

    const normalizedStatus =
      status === undefined
        ? "chua_thuc_hien"
        : status;

    if (!ALLOWED_STATUSES.includes(normalizedStatus)) {
      return sendValidationError(
        res,
        "Trạng thái công việc không hợp lệ"
      );
    }

    const normalizedPriority =
      priority === undefined
        ? "trung_binh"
        : priority;

    if (!ALLOWED_PRIORITIES.includes(normalizedPriority)) {
      return sendValidationError(
        res,
        "Mức độ ưu tiên không hợp lệ"
      );
    }

    const parsedStartDate = parseDate(startDate);
    const parsedDueDate = parseDate(dueDate);

    if (parsedStartDate === undefined) {
      return sendValidationError(
        res,
        "Ngày bắt đầu phải có định dạng YYYY-MM-DD"
      );
    }

    if (parsedDueDate === undefined) {
      return sendValidationError(
        res,
        "Hạn hoàn thành phải có định dạng YYYY-MM-DD"
      );
    }

    if (
      parsedStartDate &&
      parsedDueDate &&
      parsedDueDate < parsedStartDate
    ) {
      return sendValidationError(
        res,
        "Hạn hoàn thành không được trước ngày bắt đầu"
      );
    }

    const task = await Task.create({
      title: normalizedTitle,
      description: normalizedDescription,
      status: normalizedStatus,
      priority: normalizedPriority,
      startDate: parsedStartDate,
      dueDate: parsedDueDate,
      createdBy: req.user._id
    });

    return res.status(201).json({
      success: true,
      message: "Tạo công việc thành công",
      task
    });
  } catch (error) {
    if (error.name === "ValidationError") {
      return sendValidationError(res, error.message);
    }

    console.error("Create task error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể tạo công việc"
    });
  }
}

// ======================================================
// B2. XEM DANH SÁCH CÔNG VIỆC
// GET /api/tasks
// ======================================================

async function getTasks(req, res) {
  try {
    const query = req.query || {};

    const allowedStatuses = [
      "chua_thuc_hien",
      "dang_thuc_hien",
      "da_hoan_thanh"
    ];

    const allowedPriorities = [
      "thap",
      "trung_binh",
      "cao"
    ];

    const allowedSortFields = [
      "createdAt",
      "dueDate",
      "priority"
    ];

    // 1. Đọc tham số tìm kiếm.
    const q = query.q === undefined ? "" : query.q;
    const status = query.status;
    const priority = query.priority;

    const sortBy =
      query.sortBy === undefined
        ? "createdAt"
        : query.sortBy;

    const order =
      query.order === undefined
        ? "desc"
        : query.order;

    // 2. Kiểm tra giá trị đầu vào.
    if (
      typeof q !== "string" ||
      q.trim().length > 100
    ) {
      return sendValidationError(
        res,
        "Từ khóa tìm kiếm không hợp lệ hoặc quá 100 ký tự"
      );
    }

    if (
      status !== undefined &&
      !allowedStatuses.includes(status)
    ) {
      return sendValidationError(
        res,
        "Bộ lọc trạng thái không hợp lệ"
      );
    }

    if (
      priority !== undefined &&
      !allowedPriorities.includes(priority)
    ) {
      return sendValidationError(
        res,
        "Bộ lọc ưu tiên không hợp lệ"
      );
    }

    if (!allowedSortFields.includes(sortBy)) {
      return sendValidationError(
        res,
        "Trường sắp xếp không hợp lệ"
      );
    }

    if (order !== "asc" && order !== "desc") {
      return sendValidationError(
        res,
        "Thứ tự sắp xếp không hợp lệ"
      );
    }

    // Công việc được tạo, được giao hoặc được chia sẻ.
    const userObjectId = new mongoose.Types.ObjectId(String(req.user._id));
    const scope = query.scope;
    if (scope !== undefined && !["all","created","assigned","primary","shared"].includes(scope))
      return sendValidationError(res,"Bộ lọc vai trò không hợp lệ");

    const filters = {
      created: {createdBy:userObjectId},
      assigned: {assigneeIds:userObjectId},
      primary: {primaryAssigneeId:userObjectId},
      shared: {"shares.userId":userObjectId}
    };

    const match = scope && scope!=="all" ? filters[scope] : visibleQuery(userObjectId);

    if (query.primaryEmail !== undefined) {
      if(typeof query.primaryEmail!=="string" || query.primaryEmail.trim().length>254 ||
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(query.primaryEmail.trim()))
        return sendValidationError(res,"Email người phụ trách không hợp lệ");

      const foundPrimary=await User.findOne({
        email:query.primaryEmail.trim().toLowerCase()
      }).select("_id");

      match.primaryAssigneeId=foundPrimary
        ? foundPrimary._id
        : new mongoose.Types.ObjectId("000000000000000000000000");
    }

    if (query.primaryAssigneeId !== undefined) {
      if(!mongoose.isObjectIdOrHexString(query.primaryAssigneeId))
        return sendValidationError(res,"ID người phụ trách không hợp lệ");

      match.primaryAssigneeId = new mongoose.Types.ObjectId(query.primaryAssigneeId);
    }

    if (status !== undefined) {
      match.status = status;
    }

    if (priority !== undefined) {
      match.priority = priority;
    }

    // 4. Tìm kiếm tiêu đề, không phân biệt hoa/thường.
    const keyword = q.trim();

    if (keyword) {
      const escapedKeyword = keyword.replace(
        /[.*+?^${}()|[\]\\]/g,
        "\\$&"
      );

      match.title = {
        $regex: escapedKeyword,
        $options: "i"
      };
    }

    const direction = order === "asc" ? 1 : -1;

    // 5. Tạo pipeline tìm kiếm MongoDB.
    const pipeline = [
      { $match: match }
    ];

    // 6. Sắp xếp ưu tiên theo mức độ thực tế.
    if (sortBy === "priority") {
      pipeline.push({
        $addFields: {
          priorityRank: {
            $switch: {
              branches: [
                {
                  case: { $eq: ["$priority", "cao"] },
                  then: 3
                },
                {
                  case: {
                    $eq: ["$priority", "trung_binh"]
                  },
                  then: 2
                },
                {
                  case: { $eq: ["$priority", "thap"] },
                  then: 1
                }
              ],
              default: 0
            }
          }
        }
      });

      pipeline.push({
        $sort: {
          priorityRank: direction,
          createdAt: -1,
          _id: -1
        }
      });

      pipeline.push({
        $project: {
          priorityRank: 0
        }
      });
    }

    // 7. Sắp xếp hạn hoàn thành.
    // Công việc chưa đặt hạn luôn nằm cuối.
    else if (sortBy === "dueDate") {
      pipeline.push({
        $addFields: {
          dueDateMissing: {
            $cond: [
              { $eq: [{ $ifNull: ["$dueDate", null] }, null] },
              1,
              0
            ]
          }
        }
      });

      pipeline.push({
        $sort: {
          dueDateMissing: 1,
          dueDate: direction,
          createdAt: -1,
          _id: -1
        }
      });

      pipeline.push({
        $project: {
          dueDateMissing: 0
        }
      });
    }

    // 8. Sắp xếp thời gian tạo.
    else {
      pipeline.push({
        $sort: {
          createdAt: direction,
          _id: direction
        }
      });
    }

    // 9. Truy vấn MongoDB.
    const tasks = await Task.aggregate(pipeline);

    return res.status(200).json({
      success: true,
      message: "Lấy danh sách công việc thành công",
      total: tasks.length,
      tasks
    });

  } catch (error) {
    console.error("Get tasks error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể lấy danh sách công việc"
    });
  }
}

// ======================================================
// B3. XEM CHI TIẾT CÔNG VIỆC
// GET /api/tasks/:id
// ======================================================

async function getTaskById(req, res) {
  try {
    const taskId = req.params.id;

    if (!isValidTaskId(taskId)) {
      return sendValidationError(
        res,
        "ID công việc không hợp lệ"
      );
    }

    const task = await Task.findOne({
      _id: taskId,
      ...visibleQuery(req.user._id)
    }).lean();

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy công việc"
      });
    }

    return res.status(200).json({
      success: true,
      message: "Lấy chi tiết công việc thành công",
      role: taskRole(task,req.user._id),
      task
    });
  } catch (error) {
    console.error("Get task by ID error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể lấy chi tiết công việc"
    });
  }
}

// ======================================================
// B4. CHỈNH SỬA CÔNG VIỆC
// PATCH /api/tasks/:id
// ======================================================

async function updateTask(req, res) {
  try {
    const taskId = req.params.id;

    // 1. Kiểm tra ID.
    if (!isValidTaskId(taskId)) {
      return sendValidationError(
        res,
        "ID công việc không hợp lệ"
      );
    }

    // Người tạo hoặc người được chia sẻ quyền editor mới được sửa.
    const task = await Task.findOne({
      _id:taskId,
      ...visibleQuery(req.user._id)
    });

    if (task && !["owner","editor"].includes(taskRole(task,req.user._id))) {
      return res.status(403).json({
        success:false,
        message:"Bạn không có quyền chỉnh sửa công việc"
      });
    }

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy công việc"
      });
    }

    // D3: Ghi nhan trang thai cu truoc khi cap nhat.
    const oldStatus = task.status;

    // 3. Kiểm tra body.
    const body = req.body;

    if (
      !body ||
      typeof body !== "object" ||
      Array.isArray(body)
    ) {
      return sendValidationError(
        res,
        "Dữ liệu cập nhật không hợp lệ"
      );
    }

    const allowedFields = [
      "title",
      "description",
      "status",
      "priority",
      "startDate",
      "dueDate"
    ];

    const providedFields = Object.keys(body);

    if (providedFields.length === 0) {
      return sendValidationError(
        res,
        "Vui lòng cung cấp thông tin cần cập nhật"
      );
    }

    // Không cho sửa createdBy, _id hoặc trường ngoài danh sách.
    const invalidFields = providedFields.filter(
      (field) => !allowedFields.includes(field)
    );

    if (invalidFields.length > 0) {
      return sendValidationError(
        res,
        "Có trường dữ liệu không được phép cập nhật"
      );
    }

    // 4. Kiểm tra và cập nhật tên công việc.
    if (Object.hasOwn(body, "title")) {
      if (typeof body.title !== "string") {
        return sendValidationError(
          res,
          "Tên công việc không hợp lệ"
        );
      }

      const title = body.title.trim();

      if (title.length < 2 || title.length > 200) {
        return sendValidationError(
          res,
          "Tên công việc phải có từ 2 đến 200 ký tự"
        );
      }

      task.title = title;
    }

    // 5. Kiểm tra và cập nhật mô tả.
    if (Object.hasOwn(body, "description")) {
      if (typeof body.description !== "string") {
        return sendValidationError(
          res,
          "Mô tả công việc không hợp lệ"
        );
      }

      const description = body.description.trim();

      if (description.length > 5000) {
        return sendValidationError(
          res,
          "Mô tả không được vượt quá 5000 ký tự"
        );
      }

      task.description = description;
    }

    // 6. Cập nhật trạng thái.
    if (Object.hasOwn(body, "status")) {
      if (!ALLOWED_STATUSES.includes(body.status)) {
        return sendValidationError(
          res,
          "Trạng thái công việc không hợp lệ"
        );
      }

      task.status = body.status;
    }

    // 7. Cập nhật mức độ ưu tiên.
    if (Object.hasOwn(body, "priority")) {
      if (!ALLOWED_PRIORITIES.includes(body.priority)) {
        return sendValidationError(
          res,
          "Mức độ ưu tiên không hợp lệ"
        );
      }

      task.priority = body.priority;
    }

    // 8. Cập nhật ngày bắt đầu.
    if (Object.hasOwn(body, "startDate")) {
      const startDate = parseDate(body.startDate);

      if (startDate === undefined) {
        return sendValidationError(
          res,
          "Ngày bắt đầu phải có định dạng YYYY-MM-DD"
        );
      }

      task.startDate = startDate;
    }

    // 9. Cập nhật hạn hoàn thành.
    if (Object.hasOwn(body, "dueDate")) {
      const dueDate = parseDate(body.dueDate);

      if (dueDate === undefined) {
        return sendValidationError(
          res,
          "Hạn hoàn thành phải có định dạng YYYY-MM-DD"
        );
      }

      task.dueDate = dueDate;
    }

    // 10. Kiểm tra ngày sau cập nhật.
    if (
      task.startDate &&
      task.dueDate &&
      task.dueDate < task.startDate
    ) {
      return sendValidationError(
        res,
        "Hạn hoàn thành không được trước ngày bắt đầu"
      );
    }

    // 11. Lưu thay đổi.
    await task.save();

    // D3: Chi thong bao khi trang thai thuc su thay doi.
    let notificationResult = {
      success: true,
      created: 0
    };

    // D7: Khong gui email neu trang thai khong thay doi.
    let emailResult = {
      success: true,
      attempted: 0,
      sent: 0,
      failed: 0
    };

    if (oldStatus !== task.status) {
      const recipientIds = [
        task.createdBy,
        ...task.assigneeIds,
        task.primaryAssigneeId,
        ...task.shares.map((share) => share.userId)
      ];

      notificationResult = await notifyTaskStatusChanged({
        taskId: task._id,
        taskTitle: task.title,
        actorId: req.user._id,
        recipientIds,
        oldStatus,
        newStatus: task.status
      });

      if (!notificationResult.success) {
        console.error(
          "D3 notification warning:",
          notificationResult.message
        );
      }

      // D7: Gui email sau khi luu cong viec.
      // Loi email khong huy ket qua cap nhat.
      try {
        emailResult = await sendTaskEventEmails({
          eventType: "task_status_changed",
          taskTitle: task.title,
          actorId: req.user._id,
          recipientIds,
          oldStatus,
          newStatus: task.status
        });

        if (!emailResult.success) {
          console.error(
            "D7 status email warning: Some emails were not sent"
          );
        }
      } catch (emailError) {
        console.error(
          "D7 status email error:",
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

    return res.status(200).json({
      success: true,
      message: "Cập nhật công việc thành công",
      task,

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

  } catch (error) {
    if (error.name === "ValidationError") {
      return sendValidationError(res, error.message);
    }

    console.error("Update task error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể cập nhật công việc"
    });
  }
}

// ======================================================
// B5. XÓA CÔNG VIỆC
// DELETE /api/tasks/:id
// ======================================================

async function deleteTask(req, res) {
  try {
    const taskId = req.params.id;

    // 1. Kiểm tra ID công việc.
    if (!isValidTaskId(taskId)) {
      return sendValidationError(
        res,
        "ID công việc không hợp lệ"
      );
    }

    // 2. Chỉ xóa công việc do tài khoản hiện tại tạo.
    // Điều kiện quyền sở hữu nằm trực tiếp trong truy vấn.
    const deletedTask = await Task.findOneAndDelete({
      _id: taskId,
      createdBy: req.user._id
    });

    // 3. Công việc không tồn tại hoặc không thuộc tài khoản.
    if (!deletedTask) {
      return res.status(404).json({
        success: false,
        message: "Không tìm thấy công việc"
      });
    }

    // 4. Trả về kết quả xóa thành công.
    return res.status(200).json({
      success: true,
      message: "Xóa công việc thành công",
      taskId: deletedTask._id.toString()
    });

  } catch (error) {
    console.error("Delete task error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Không thể xóa công việc"
    });
  }
}

// ======================================================
// EXPORT CONTROLLERS
// ======================================================

module.exports = {
  createTask,
  getTasks,
  getTaskById,
  updateTask,
  deleteTask
};
