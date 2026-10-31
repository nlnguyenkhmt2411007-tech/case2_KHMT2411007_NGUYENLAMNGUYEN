
require("dotenv").config();

const app = require("./app");

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log("--------------------------------");
  console.log("Task Manager Backend");
  console.log(`Server: http://localhost:${PORT}`);
  console.log(`Health API: http://localhost:${PORT}/api/health`);
  console.log("--------------------------------");
});
