const crypto = require("crypto");
exports.generateSalt = () => crypto.randomBytes(16).toString("hex");
exports.hashPassword = (password, salt) =>
  crypto.pbkdf2Sync(password, salt, 200000, 32, "sha256").toString("hex");