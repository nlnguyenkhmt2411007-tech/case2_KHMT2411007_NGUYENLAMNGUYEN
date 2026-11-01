
require("dotenv").config({ quiet: true });

const app = require("./app");
const connectDatabase = require("./config/database");

const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    // Kết nối MongoDB trước khi khởi động API
    await connectDatabase();

    const server = app.listen(PORT, () => {
      console.log("--------------------------------");
      console.log("Task Manager Backend");
      console.log(`Server: http://localhost:${PORT}`);
      console.log(`Health API: http://localhost:${PORT}/api/health`);
      console.log("--------------------------------");
    });

    server.on("error", (error) => {
      console.error("Lỗi khởi động HTTP server:", error.message);
      process.exit(1);
    });
  } catch (error) {
    console.error("Không thể khởi động backend:", error.message);
    process.exit(1);
  }
}

startServer();
