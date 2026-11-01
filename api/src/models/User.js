
const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, "Vui lòng nhập họ tên"],
      trim: true
    },

    email: {
      type: String,
      required: [true, "Vui lòng nhập email"],
      unique: true,
      lowercase: true,
      trim: true
    },

    passwordHash: {
      type: String,
      required: true,
      select: false
    },

    avatarUrl: {
      type: String,
      default: ""
    }
  },
  {
    timestamps: true,
    collection: "users"
  }
);

module.exports = mongoose.model("User", userSchema);
