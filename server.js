const os = require("os");
const express = require("express");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const pool = require("./db");
const { exec } = require("child_process");
const { generateSalt, hashPassword } = require("./crypto");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

const app = express();
app.use(cors({
  origin: [/^https:\/\/.*\.ngrok-free\.dev$/],
  credentials: true
}));

function getLogFilePath() {
  const now = new Date();
  const day = String(now.getDate()).padStart(2, "0");
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const year = now.getFullYear();
  return path.join(LOG_DIR, `${day}-${month}-${year}.log`);
}

function writeLog(message) {
  const now = new Date();
  const time = now.toTimeString().split(" ")[0];
  const line = `[${time}]: ${message}\n`;
  fs.appendFileSync(getLogFilePath(), line);
}

app.use(cookieParser());
app.use(express.json());

const PROJECTS_ROOT = path.join(__dirname, "projects");
if (!fs.existsSync(PROJECTS_ROOT)) fs.mkdirSync(PROJECTS_ROOT);

let sessions = {}; // session_id => username

// ==================== Archivos por defecto ====================
const LANGUAGES = {
  lua: `-- main.lua por defecto
print("Lua")`,

  c_cpp_c: `#include <stdio.h>
int main(){
    printf("C\\n");
    return 0;
}`,

  c_cpp_cpp: `#include <iostream>
int main(){
    std::cout << "C++" << std::endl;
    return 0;
}`,

  java: `public class main {
    public static void main(String[] args){
        System.out.println("Java");
    }
}`,

  javascript: `console.log("JavaScript");`,

  python: `print("Python")`,

  ruby: `puts "Ruby"`
};

function getExt(lang) {
  switch (lang) {
    case "c_cpp_c": return "c";
    case "c_cpp_cpp": return "cpp";
    case "java": return "java";
    case "javascript": return "js";
    case "lua": return "lua";
    case "python": return "py";
    case "ruby": return "rb";
    default: return "txt";
  }
}

// ==================== Manejo de directorios ====================
function ensureSessionDirs(sessionId) {
  const sessionPath = path.join(PROJECTS_ROOT, sessionId);
  if (!fs.existsSync(sessionPath)) {
    fs.mkdirSync(sessionPath, { recursive: true });
  }

  // Crear carpetas por lenguaje
  for (const lang of Object.keys(LANGUAGES)) {
    const langDir = path.join(sessionPath, lang);
    if (!fs.existsSync(langDir)) {
      fs.mkdirSync(langDir, { recursive: true });
    }
  }

  // Crear main.<ext> si no existe
  for (const [lang, content] of Object.entries(LANGUAGES)) {
    const mainFile = path.join(
      sessionPath,
      lang,
      "main." + getExt(lang)
    );
    if (!fs.existsSync(mainFile)) {
      fs.writeFileSync(mainFile, content, "utf8");
    }
  }

  return sessionPath;
}

function createFile(sessionId, language, filename, content) {
  if (!LANGUAGES[language]) {
    throw new Error("Lenguaje inválido");
  }

  if (!filename || filename.includes("..")) {
    throw new Error("Nombre de archivo inválido");
  }

  const sessionPath = ensureSessionDirs(sessionId);
  const langDir = path.join(sessionPath, language);

  if (!fs.existsSync(langDir)) {
    fs.mkdirSync(langDir, { recursive: true });
  }

  const filePath = path.join(langDir, filename);
  if (fs.existsSync(filePath)) {
    throw new Error("Archivo ya existe");
  }

  fs.writeFileSync(filePath, content ?? "", "utf8");
  return filePath;
}

// ==================== Construir árbol tipo VSCode ====================
function buildTreeFromFS(sessionId) {
  const sessionPath = path.join(PROJECTS_ROOT, sessionId);
  if (!fs.existsSync(sessionPath)) return [];

  const username = sessions[sessionId];

  const walk = (currentPath) => {
    const stat = fs.statSync(currentPath);
    const isRoot = currentPath === sessionPath;
    const name = isRoot ? username : path.basename(currentPath);

    if (stat.isDirectory()) {
      return {
        name,
        type: "directory",
        isRoot,
        children: fs.readdirSync(currentPath).map(f =>
          walk(path.join(currentPath, f))
        )
      };
    }

    const ext = path.extname(currentPath).slice(1);
    const language =
      Object.keys(LANGUAGES).find(l => getExt(l) === ext) || "txt";

    return {
      name,
      type: "file",
      language,
      content: fs.readFileSync(currentPath, "utf8")
    };
  };

  return [walk(sessionPath)];
}

async function requireAuth(req, res, next) {
  const sid = req.cookies.sid;

  if (!sid) return res.status(401).json({ error: "No autenticado" });

  const user = await getUserFromSession(sid);

  if (!user) return res.status(401).json({ error: "No autenticado" });

  req.user = user;
  req.sid = sid;

  next();
}

async function getUserFromSession(sid) {
  if (!sid) return null;

  if (sessions[sid]) return sessions[sid];

  let conn;
  try {
    conn = await pool.getConnection();
    const rows = await conn.query("SELECT username, salt, password_hash FROM users");

    for (const user of rows) {
      const computedSid = crypto
        .createHash("sha256")
        .update(user.password_hash + user.salt)
        .digest("hex");

      if (computedSid === sid) {
        sessions[sid] = user.username; // rehidrata
        return user.username;
      }
    }
  } finally {
    if (conn) conn.release();
  }

  return null;
}

// ==================== Auth ====================
app.post("/api/register", async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: "Datos incompletos" });
  }

  let conn;
  try {
    conn = await pool.getConnection();
    const rows = await conn.query(
      "SELECT id FROM users WHERE username=?",
      [username]
    );
    if (rows.length) {
      return res.status(409).json({ error: "Usuario ya existe" });
    }

    const salt = generateSalt();
    const hash = hashPassword(password, salt);

    await conn.query(
      "INSERT INTO users (username, salt, password_hash) VALUES (?, ?, ?)",
      [username, salt, hash]
    );

    const sid = crypto.createHash("sha256").update(hash + salt).digest("hex");
    sessions[sid] = username;

    ensureSessionDirs(sid);

    res.cookie("sid", sid, {
      httpOnly: true,
      sameSite: "None", // necesario para cross-site (ngrok)
      secure: true,     // HTTPS
      path: "/",
      maxAge: 86400000
    });
    writeLog(`usuario ${username} registrado.`);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    writeLog("error al registrar usuario.");
    res.status(500).json({ error: "Error servidor" });
  } finally {
    if (conn) conn.release();
  }
});

app.post("/api/login", async (req, res) => {
  const { username, password } = req.body;
  let conn;

  try {
    conn = await pool.getConnection();
    const rows = await conn.query(
      "SELECT * FROM users WHERE username=?",
      [username]
    );
    if (!rows.length) {
      writeLog(`error de credenciales inválidas para usuario ${username}.`);
      return res.status(401).json({ error: "Credenciales inválidas" });
    }

    const user = rows[0];
    const hash = hashPassword(password, user.salt);
    if (hash !== user.password_hash) {
      writeLog(`error de credenciales inválidas para usuario ${username}.`);
      return res.status(401).json({ error: "Credenciales inválidas" });
    }

    const sid = crypto.createHash("sha256").update(hash + user.salt).digest("hex");
    sessions[sid] = username;

    ensureSessionDirs(sid);

    res.cookie("sid", sid, {
      httpOnly: true,
      sameSite: "None", // necesario para cross-site (ngrok)
      secure: true,     // HTTPS
      path: "/",
      maxAge: 86400000
    });

    writeLog(`usuario ${username} ha iniciado sesión.`);

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    writeLog("error interno en login.");
    res.status(500).json({ error: "Error servidor" });
  } finally {
    if (conn) conn.release();
  }
});

app.get("/api/session", async (req, res) => {
  const sid = req.cookies.sid;
  const user = await getUserFromSession(sid);
  if (!user) return res.status(401).json({ logged: false });

  if (sid && user) {
    res.json({ logged: true, user: user });
  } else {
    res.status(401).json({ logged: false });
  }
});

app.post("/api/logout", (req, res) => {
  const sid = req.cookies.sid;
  const username = sessions[sid];

  delete sessions[sid];
  res.clearCookie("sid");

  if (username) {
    writeLog(`usuario ${username} cerró sesión.`);
  }

  res.json({ success: true });
});

// ==================== Archivos ====================
app.post("/api/file/new", requireAuth, async (req, res) => {
  const { language, filename, content } = req.body;

  try {
    const finalPath = createFile(req.sid, language, filename, content);
    res.json({ success: true, path: finalPath });
  } catch (err) {
    console.error(err);
    res.status(400).json({ error: err.message });
  }
});

app.post("/api/file/save", requireAuth, async (req, res) => {
  const { language, filename, content } = req.body;

  if (!language || !filename) {
    return res.status(400).json({ error: "Datos incompletos" });
  }

  if (filename.includes("..") || filename.includes("/") || filename.includes("\\")) {
    return res.status(400).json({ error: "Nombre de archivo inválido" });
  }

  try {
    const filePath = path.join(
      PROJECTS_ROOT,
      req.sid,
      language,
      filename
    );

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: "Archivo no existe" });
    }

    fs.writeFileSync(filePath, content ?? "", "utf8");
    res.json({ success: true });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "No se pudo guardar" });
  }
});

app.post("/api/file/read", requireAuth, async (req, res) => {
  const { language, filename } = req.body;

  if (!language || !filename) {
    return res.status(400).json({ error: "Datos incompletos" });
  }

  if (
    filename.includes("..") ||
    filename.includes("/") ||
    filename.includes("\\")
  ) {
    return res.status(400).json({ error: "Nombre de archivo inválido" });
  }

  const filePath = path.join(PROJECTS_ROOT, req.sid, language, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "Archivo no existe" });
  }

  const content = fs.readFileSync(filePath, "utf8");
  res.json({ content });
});

app.get("/api/files", requireAuth, async (req, res) => {
  ensureSessionDirs(req.sid);
  res.json(buildTreeFromFS(req.sid));
});

// ==================== RENOMBRAR ARCHIVO MANTENIENDO EXT ====================
app.post("/api/file/rename", requireAuth, async (req, res) => {
  const { language, oldName, newName } = req.body;

  if (!language || !oldName || !newName) {
    return res.status(400).json({ error: "Datos incompletos" });
  }

  if ([oldName, newName].some(n => n.includes("..") || n.includes("/") || n.includes("\\"))) {
    return res.status(400).json({ error: "Nombre de archivo inválido" });
  }

  // Mantener la extensión original
  const ext = path.extname(oldName);
  const baseNewName = path.parse(newName).name; // solo la parte sin extensión
  const finalName = baseNewName + ext;

  const oldPath = path.join(PROJECTS_ROOT, req.sid, language, oldName);
  const newPath = path.join(PROJECTS_ROOT, req.sid, language, finalName);

  if (!fs.existsSync(oldPath)) return res.status(404).json({ error: "Archivo no existe" });
  if (fs.existsSync(newPath)) return res.status(409).json({ error: "Archivo destino ya existe" });

  try {
    fs.renameSync(oldPath, newPath);
    writeLog(`usuario ${req.user} renombró archivo ${oldName} → ${finalName}`);
    res.json({ success: true, newName: finalName });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error renombrando archivo" });
  }
});

// Eliminar archivo
app.post("/api/file/delete", requireAuth, async (req, res) => {
  const { language, filename } = req.body;
  if (!language || !filename) return res.status(400).json({ error: "Datos incompletos" });

  if (filename.includes("..") || filename.includes("/") || filename.includes("\\")) {
    return res.status(400).json({ error: "Nombre de archivo inválido" });
  }

  const filePath = path.join(PROJECTS_ROOT, req.sid, language, filename);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: "Archivo no existe" });

  try {
    fs.unlinkSync(filePath);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "No se pudo eliminar archivo" });
  }
});

app.get("/api/file", requireAuth, async (req, res) => {
  // const sid = req.cookies.sid;
  // const user = await getUserFromSession(sid);
  // if (!sid || !user) return res.status(401);

  const { language, name } = req.query;
  if (!language || !name) return res.status(400);

  const filePath = path.join(PROJECTS_ROOT, req.sid, language, name);
  if (name.includes("..") || name.includes("/") || name.includes("\\")) {
    return res.status(400).json({ error: "Nombre de archivo inválido" });
  }

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "Archivo no existe" });
  }

  const content = fs.readFileSync(filePath, "utf8");
  res.json({ content });
});


// ==================== Lenguajes ====================
app.get("/api/languages", (_, res) => {
  const langs = {};
  for (const [lang, template] of Object.entries(LANGUAGES)) {
    langs[lang] = { template, ext: getExt(lang) };
  }
  res.json({ languages: langs });
});

// ================ Plugins (extras) =================
app.get("/api/stats/files", requireAuth, async (req, res) => {
  const baseDir = path.join(PROJECTS_ROOT, req.sid); // req.sid ya está definido
  const stats = {};
  let total = 0;

  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(fullPath);
      else {
        total++;
        const ext = path.extname(entry.name) || "sin_ext";
        stats[ext] = (stats[ext] || 0) + 1;
      }
    }
  }

  try {
    walk(baseDir);
    res.json({ total, stats });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error al calcular estadísticas" });
  }
});

// ==================== DB Stats ====================
app.get("/api/stats/database", requireAuth, async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

    const users = await conn.query("SELECT COUNT(*) as total FROM users");
    const lastUsers = await conn.query(
      "SELECT username FROM users ORDER BY id DESC LIMIT 5"
    );

    res.json({
      totalUsers: Number(users[0].total),
      lastUsers: lastUsers.map(u => u.username)
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error consultando base de datos" });
  } finally {
    if (conn) conn.release();
  }
});

// ====================== HARDWARE ======================
app.get("/api/stats/hardware", requireAuth, async (req, res) => {
  try {
    const cpuLoad = os.loadavg()[0];
    const totalRAM = os.totalmem();
    const freeRAM = os.freemem();
    const uptime = os.uptime();

    res.json({
      cpuLoad: cpuLoad.toFixed(2),
      totalRAM,
      freeRAM,
      usedRAM: totalRAM - freeRAM,
      uptime
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error al obtener stats de hardware" });
  }
});

app.get("/api/stats/mariadb", requireAuth, async (req, res) => {
  const sid = req.cookies.sid;
  const user = await getUserFromSession(sid);
  if (!sid || !user) return res.status(401).json({ error: "No autenticado" });

  try {
    // Intentar ambos nombres de proceso: mariadbd o mysqld
    exec(`ps -C mariadbd,mysqld -o %cpu=,%mem=,etimes=`, (err, stdout) => {
      if (err) {
        console.error("Error al ejecutar ps:", err);
        return res.status(500).json({ error: "No se pudo obtener stats MariaDB" });
      }

      if (!stdout.trim()) {
        return res.status(500).json({ error: "Proceso MariaDB no encontrado" });
      }

      let cpu = 0, ram = 0, uptime = 0;
      const lines = stdout.trim().split("\n");
      lines.forEach(line => {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 3) {
          cpu += parseFloat(parts[0]) || 0;
          ram += parseFloat(parts[1]) || 0;
          uptime = Math.max(uptime, parseInt(parts[2]) || 0);
        }
      });

      res.json({
        cpu: cpu.toFixed(2),
        ramPercent: ram.toFixed(2),
        uptimeSeconds: uptime
      });
    });

  } catch (err) {
    console.error("Error interno endpoint MariaDB:", err);
    res.status(500).json({ error: "Error obteniendo stats MariaDB" });
  }
});

app.listen(3000, () =>
  console.log("Backend en http://localhost:3000")
);