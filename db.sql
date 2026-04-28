DROP USER IF EXISTS 'ide_user'@'localhost';
CREATE USER 'ide_user'@'localhost' IDENTIFIED BY 'ide_pass';
CREATE DATABASE IF NOT EXISTS ide_auth
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ide_auth.* TO 'ide_user'@'localhost';
FLUSH PRIVILEGES;

USE ide_auth;
CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  salt CHAR(32) NOT NULL,
  password_hash CHAR(64) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;