const mongoose = require("mongoose");
const Task = require("../models/Task");
const validId = (id) => typeof id === "string" && mongoose.isObjectIdOrHexString(id);
const eq = (a,b) => a && b && String(a) === String(b);
function taskRole(task, userId) {
  if (eq(task.createdBy, userId)) return "owner";
  const share = (task.shares || []).find(s => eq(s.userId, userId));
  if (share) return share.role;
  if (eq(task.primaryAssigneeId, userId)) return "assignee";
  if ((task.assigneeIds || []).some(id => eq(id,userId))) return "assignee";
  return null;
}
function visibleQuery(userId) {
  return { $or: [{ createdBy: userId }, { assigneeIds: userId },
    { primaryAssigneeId: userId }, { "shares.userId": userId }] };
}
async function requireTask(req,res,next) {
  if (!validId(req.params.id)) return res.status(400).json({ success:false, message:"ID công việc không hợp lệ" });
  try {
    const task=await Task.findById(req.params.id);
    const role=task && taskRole(task,req.user._id);
    if (!role) return res.status(404).json({ success:false, message:"Không tìm thấy công việc" });
    req.task=task;req.taskRole=role;next();
  } catch(err) { console.error("Task access:",err.message);res.status(500).json({success:false,message:"Không thể kiểm tra quyền công việc"}); }
}
const requireOwner = (req,res,next) => req.taskRole === "owner" ? next() : res.status(403).json({success:false,message:"Chỉ người tạo công việc được thao tác"});
const requireEditor = (req,res,next) => ["owner","editor"].includes(req.taskRole) ? next() : res.status(403).json({success:false,message:"Bạn không có quyền chỉnh sửa"});
module.exports={validId,eq,taskRole,visibleQuery,requireTask,requireOwner,requireEditor};
