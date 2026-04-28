const mariadb = require("mariadb");
module.exports = mariadb.createPool({
  host: "localhost",
  user: "ide_user",
  password: "ide_pass",
  database: "ide_auth",
  connectionLimit: 5
});