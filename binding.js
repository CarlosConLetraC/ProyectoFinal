const openTabs = new Map();
let activeTab = null;
let currentSession = null;
const TREE_CONTAINER = document.getElementById("explorerTree");
let aceEditor;
let fontSize = parseInt(localStorage.getItem("fontSize") || "24");
let suppressChange = false;

// ==================== SESSION ====================
async function checkSession() {
  try {
    const res = await fetch("/api/session", { credentials: "include" });
    if (!res.ok) throw new Error();
    const data = await res.json();
    currentSession = data.user;
    showIDE();
  } catch {
    currentSession = null;
    showLogin();
  }
}

async function loginUser() {
  const res = await fetch("/api/login", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      username: usernameEl.value,
      password: passwordEl.value
    })
  });

  if (!res.ok) {
    alert("Login inválido");
    return;
  }

  currentSession = usernameEl.value;
  showIDE();
  setTimeout(checkSession, 50);
}

async function registerUser() {
  const res = await fetch("/api/register", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      username: usernameEl.value,
      password: passwordEl.value
    })
  });
  if (!res.ok) return alert("Registro fallido");
  await checkSession();
}

async function logoutUser() {
  await fetch("/api/logout", { method: "POST", credentials: "include" });
  showLogin();
}

// ==================== UI ====================
function showLogin() {
  authView.style.display = "block";
  ideContainer.style.display = "none";
}

function showIDE() {
  document.getElementById("statusUser").textContent = `Usuario: ${currentSession}`;
  authView.style.display = "none";
  ideContainer.style.display = "flex";
  loadFiles();
}

// ==================== FILE EXPLORER ====================
function getFileKey(file) { return `${file.language}/${file.name}`; }

function activateTab(key) {
  const tab = openTabs.get(key);
  if (!tab) return;

  activeTab = key;

  document.querySelectorAll(".tab").forEach(t =>
    t.classList.remove("active")
  );
  tab.tabEl.classList.add("active");

  suppressChange = true;
  aceEditor.setValue(tab.content || "", -1);
  suppressChange = false;

  aceEditor.session.setMode("ace/mode/" + mapAceLanguage(tab.language));

  aceEditor.setReadOnly(!!tab.readonly);
  aceEditor.focus();
  languageSelect.value = tab.language;
}

function closeTab(key, skipSavePrompt = false) {
  const tab = openTabs.get(key);
  if (!tab) return;

  // ⚡ Solo preguntar si es dirty y no se indica skip
  if (!skipSavePrompt && tab.dirty && !tab.temporary) {
    const saveBeforeClose = confirm(
      `¿Deseas guardar los cambios en "${tab.name}" antes de cerrar?`
    );
    if (saveBeforeClose) saveCurrentFile();
  }

  tab.tabEl.remove();
  openTabs.delete(key);

  if (activeTab === key) {
    const last = [...openTabs.keys()].pop();
    if (last) activateTab(last);
    else {
      aceEditor.setValue("", -1); // editor limpio si no hay tabs
      activeTab = null;
    }
  }
}

async function openStatsTab() {
  const res = await fetch("/api/stats/files", {
    credentials: "include"
  });

  if (!res.ok) {
    alert("No se pudieron cargar las estadísticas");
    return;
  }

  const data = await res.json();

  let content = "Estadísticas de la sesión\n\n";
  content += `Total de archivos: ${data.total}\n\n`;

  for (const ext in data.stats) {
    content += `${ext} → ${data.stats[ext]}\n`;
  }

  const key = "__stats__";

  if (openTabs.has(key)) {
    activateTab(key);
    return;
  }

  const tabEl = document.createElement("div");
  tabEl.className = "tab";

  const titleEl = document.createElement("span");
  titleEl.textContent = "Estadísticas";
  tabEl.appendChild(titleEl);

  const closeBtn = document.createElement("span");
  closeBtn.textContent = " ×";
  tabEl.appendChild(closeBtn);

  document.getElementById("tabs")
    .insertBefore(tabEl, document.getElementById("addTab"));

  openTabs.set(key, {
    key,
    name: "Estadísticas",
    language: "text",
    content,
    dirty: false,
    tabEl,
    titleEl,
    readonly: true
  });

  tabEl.onclick = () => activateTab(key);
  closeBtn.onclick = (e) => {
    e.stopPropagation();
    closeTab(key);
  };

  activateTab(key);
}

function markTabDirty(tab) {
  if (!tab.titleEl.textContent.endsWith("*")) {
    tab.titleEl.textContent = tab.name + "*";
  }
}

function markTabClean(tab) {
  tab.titleEl.textContent = tab.name;
}

async function deleteFile(tab) {
  if (!confirm(`¿Eliminar archivo ${tab.name}?`)) return;

  const res = await fetch("/api/file/delete", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      language: tab.language,
      filename: tab.name
    })
  });

  if (!res.ok) {
    const { error } = await res.json();
    alert("Error eliminando archivo: " + error);
    return;
  }

  closeTab(tab.key);
  loadFiles();
}

async function renameFile(tabOrFile) {
  // tabOrFile puede ser: tab del openTabs o file del explorer
  const language = tabOrFile.language;
  const oldName = tabOrFile.name;

  // Separar nombre base y extensión
  const ext = oldName.includes(".") ? "." + oldName.split(".").pop() : "";
  const baseName = oldName.replace(ext, "");

  const newBase = prompt("Nuevo nombre de archivo:", baseName);
  if (!newBase || newBase === baseName) return;

  const newName = newBase + ext;

  try {
    const res = await fetch("/api/file/rename", {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        language,
        oldName,
        newName
      })
    });

    if (!res.ok) {
      const data = await res.json();
      return alert("Error renombrando archivo: " + (data?.error || res.status));
    }

    const data = await res.json();

    // Si es tab del openTabs, actualizar datos
    if (tabOrFile.key) {
      const tab = openTabs.get(tabOrFile.key);
      if (!tab) return;

      tab.name = data.newName;
      tab.titleEl.textContent = data.newName;

      // Actualizar key en openTabs
      const oldKey = tab.key;
      const newKey = `${tab.language}/${tab.name}`;
      openTabs.delete(oldKey);
      tab.key = newKey;
      openTabs.set(newKey, tab);
      if (activeTab === oldKey) activeTab = newKey;
    }

    // Recargar explorer
    await loadFiles();
  } catch (err) {
    console.error(err);
    alert("Error renombrando archivo");
  }
}

async function openFile(file) {
  if (!file || file.type !== "file") return;

  const key = getFileKey(file);

  if (openTabs.has(key)) {
    activateTab(key);
    return;
  }

  const res = await fetch("/api/file/read", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      language: file.language,
      filename: file.name
    })
  });

  if (!res.ok) {
    alert("No se pudo abrir el archivo");
    return;
  }

  const { content } = await res.json();

  // crear pestaña
  const tabEl = document.createElement("div");
  tabEl.className = "tab";

  const titleEl = document.createElement("span");
  titleEl.textContent = file.name;
  tabEl.appendChild(titleEl);

  const closeBtn = document.createElement("span");
  closeBtn.textContent = " ×";
  tabEl.appendChild(closeBtn);

  document.getElementById("tabs").insertBefore(
    tabEl,
    document.getElementById("addTab")
  );

  openTabs.set(key, {
    key,
    name: file.name,
    language: file.language,
    content,
    dirty: false,
    tabEl,
    titleEl
  });

  tabEl.onclick = () => activateTab(key);
    closeBtn.onclick = (e) => {
      e.stopPropagation();
      closeTab(key);
    };

    titleEl.ondblclick = (e) => {
    e.stopPropagation();
    const tab = openTabs.get(key);
    if (!tab) return;

    renameFile(tab);
  };

  activateTab(key);
}

function renderNode(node, parent) {
  const item = document.createElement("div");
  item.className = "tree-item";

  const label = document.createElement("span");
  label.textContent = node.name || node.language || "root";
  item.appendChild(label);
  parent.appendChild(item);

  if (node.type === "directory" && Array.isArray(node.children)) {
    const children = document.createElement("div");
    children.className = "tree-children";
    parent.appendChild(children);

    item.onclick = () => {
      children.classList.toggle("open");
    };

    node.children.forEach(child => renderNode(child, children));
  }

  if (node.type === "file") {
    // CLIC DERECHO → Menú contextual
    item.oncontextmenu = (e) => {
      e.preventDefault();

      // eliminar menú antiguo
      const oldMenu = document.getElementById("contextMenu");
      if (oldMenu) oldMenu.remove();

      // crear menú
      const menu = document.createElement("div");
      menu.id = "contextMenu";
      menu.style.position = "absolute";
      menu.style.left = e.pageX + "px";
      menu.style.top = e.pageY + "px";
      menu.style.background = "#333";
      menu.style.color = "#fff";
      menu.style.padding = "5px";
      menu.style.borderRadius = "5px";
      menu.style.zIndex = 1000;
      menu.style.userSelect = "none"; // evita selección al hacer clic
      menu.style.minWidth = "100px";

      // función auxiliar para crear opción
      const createOption = (text, onClick) => {
        const option = document.createElement("div");
        option.textContent = text;
        option.style.padding = "4px 8px";
        option.style.cursor = "pointer"; // ← esto cambia el cursor
        option.onmouseover = () => option.style.background = "#555";
        option.onmouseout = () => option.style.background = "#333";
        option.onclick = onClick;
        return option;
      };

      // Renombrar
      menu.appendChild(createOption("Renombrar", async () => {
        await renameFile(node);
        menu.remove();
      }));

      // Eliminar
      menu.appendChild(createOption("Eliminar", async () => {
        await deleteFile(node);
        menu.remove();
      }));

      document.body.appendChild(menu);

      // clic afuera cierra el menú
      document.addEventListener("click", () => menu.remove(), { once: true });
    };

    // CLIC IZQUIERDO → Abrir archivo
    item.onclick = (e) => {
      e.stopPropagation();
      openFile(node);
    };
  }
}

/*
function getIcon(node) {
  if (node.type === "directory") return node.isRoot ? "👤" : "📁";
  switch (node.language) {
    case "javascript": return "🟨";
    case "python": return "🐍";
    case "java": return "☕";
    case "lua": return "🌙";
    case "ruby": return "💎";
    case "c_cpp_c":
    case "c_cpp_cpp": return "📘";
    default: return "📄";
  }
}
*/

// ==================== EDITOR ====================
async function loadFiles() {
  const res = await fetch("/api/files", { credentials: "include" });
  if (res.status === 401) {
    showLogin();
    return;
  }

  const tree = await res.json();
  TREE_CONTAINER.innerHTML = "";
  TREE_CONTAINER.className = "tree";

  if (tree.length) {
    renderNode(tree[0], TREE_CONTAINER);
  }
}

function mapAceLanguage(lang) {
  return lang.startsWith("c_cpp") ? "c_cpp" : lang;
}

// ==================== LANGUAGE SELECT ====================
const languageSelect = document.getElementById("languageSelect");

languageSelect.addEventListener("change", () => {
  if (!activeTab) return;

  const tab = openTabs.get(activeTab);
  if (!tab) return;

  tab.language = languageSelect.value;

  aceEditor.session.setMode(
    "ace/mode/" + mapAceLanguage(tab.language)
  );

  tab.dirty = true;
  markTabDirty(tab);
});

// ==================== CREATE FILE ====================
async function createNewFile() {
  const language = languageSelect.value;
  const ext = getExtFromLanguage(language);
  const filename = prompt(`Nombre del archivo (.${ext})`);
  if (!filename) return;

  const finalName = filename.endsWith(`.${ext}`)
    ? filename
    : `${filename}.${ext}`;

  const res = await fetch("/api/file/new", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ language, filename: finalName, content: "" })
  });

  if (!res.ok) {
    alert("No se pudo crear el archivo");
    return;
  }

  await loadFiles();
}

async function quickCreateFile() {
  const language = languageSelect.value;
  const ext = getExtFromLanguage(language);

  const filename = `main.${ext}`;

  const res = await fetch("/api/file/new", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      language,
      filename,
      content: ""
    })
  });

  if (!res.ok) {
    alert("No se pudo crear el archivo");
    return;
  }

  await loadFiles();
}

async function createTempTab() {
  const language = languageSelect.value;

  // Nombre temporal tipo "Untitled", sin extensión
  const filename = `Untitled-${Date.now()}`;

  const key = `temp/${filename}`;

  // crear pestaña en memoria
  const tabEl = document.createElement("div");
  tabEl.className = "tab";

  const titleEl = document.createElement("span");
  titleEl.textContent = filename;
  tabEl.appendChild(titleEl);

  const closeBtn = document.createElement("span");
  closeBtn.textContent = " ×";
  tabEl.appendChild(closeBtn);

  document.getElementById("tabs").insertBefore(
    tabEl,
    document.getElementById("addTab")
  );

  openTabs.set(key, {
    key,
    name: filename,
    language,
    content: "",
    dirty: false,
    tabEl,
    titleEl,
    temporary: true
  });

  tabEl.onclick = () => activateTab(key);
  closeBtn.onclick = (e) => {
    e.stopPropagation();
    closeTab(key);
  };

  activateTab(key);
}

async function saveCurrentFile() {
  if (!activeTab) return false;

  const tab = openTabs.get(activeTab);
  if (!tab || tab.readonly) return false;

  if (tab.temporary) {
    const ext = getExtFromLanguage(tab.language);
    let filename = prompt("Nombre del archivo:", tab.name);
    if (!filename) return false;

    if (!filename.includes(".")) filename += "." + ext;

    const res = await fetch("/api/file/new", {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        language: tab.language,
        filename,
        content: tab.content
      })
    });

    if (!res.ok) {
      const data = await res.json();
      alert("No se pudo guardar: " + (data?.error || res.status));
      return false;
    }

    // ⚡ Actualizar tab en memoria y DOM
    const oldKey = tab.key;
    tab.name = filename;
    tab.key = `${tab.language}/${filename}`;
    tab.temporary = false;
    tab.dirty = false;
    markTabClean(tab);
    tab.titleEl.textContent = filename;

    openTabs.delete(oldKey);
    openTabs.set(tab.key, tab);

    await loadFiles();
    activateTab(tab.key);

    return true;
  }

  // Guardar archivo real
  const res = await fetch("/api/file/save", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      language: tab.language,
      filename: tab.name,
      content: tab.content
    })
  });

  if (!res.ok) {
    alert("Error al guardar archivo");
    return false;
  }

  tab.dirty = false;
  markTabClean(tab);
  return true;
}

async function openDatabaseStatsTab() {
  const res = await fetch("/api/stats/database", {
    credentials: "include"
  });

  if (!res.ok) {
    alert("No se pudo cargar información de la base de datos");
    return;
  }

  const data = await res.json();

  let content = "Uso de Base de Datos\n\n";
  content += `Total de usuarios registrados: ${data.totalUsers}\n\n`;
  content += "Últimos usuarios registrados:\n";

  data.lastUsers.forEach(u => {
    content += ` - ${u}\n`;
  });

  const key = "__dbstats__";

  if (openTabs.has(key)) {
    activateTab(key);
    return;
  }

  const tabEl = document.createElement("div");
  tabEl.className = "tab";

  const titleEl = document.createElement("span");
  titleEl.textContent = "Base de Datos";
  tabEl.appendChild(titleEl);

  const closeBtn = document.createElement("span");
  closeBtn.textContent = " ×";
  tabEl.appendChild(closeBtn);

  document.getElementById("tabs")
    .insertBefore(tabEl, document.getElementById("addTab"));

  openTabs.set(key, {
    key,
    name: "Base de Datos",
    language: "text",
    content,
    dirty: false,
    tabEl,
    titleEl,
    readonly: true
  });

  tabEl.onclick = () => activateTab(key);
  closeBtn.onclick = (e) => {
    e.stopPropagation();
    closeTab(key);
  };

  activateTab(key);
}

async function updateHardwareStatus() {
  try {
    // hardware general
    const res = await fetch("/api/stats/hardware", { credentials: "include" });
    if (!res.ok) return;
    const data = await res.json();

    document.getElementById("statusCPU").textContent = `CPU: ${data.cpuLoad}`;
    document.getElementById("statusRAM").textContent = `RAM: ${((data.usedRAM/1024/1024).toFixed(0))}/${((data.totalRAM/1024/1024).toFixed(0))} MB`;
    document.getElementById("statusUptime").textContent = `Uptime: ${Math.floor(data.uptime/60)}m`;

    // MariaDB
    const resDB = await fetch("/api/stats/mariadb", { credentials: "include" });
    if (!resDB.ok) return;
    const dbData = await resDB.json();

    document.getElementById("statusMariaCPU").textContent = `MariaDB CPU: ${dbData.cpu}%`;
    document.getElementById("statusMariaRAM").textContent = `MariaDB RAM: ${dbData.ramPercent}%`;
    document.getElementById("statusMariaUptime").textContent = `MariaDB Uptime: ${Math.floor(dbData.uptimeSeconds/60)}m`;

  } catch (err) {
    console.error("Hardware status error", err);
  }
}

function getExtFromLanguage(lang) {
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

// ==================== INIT ====================
const usernameEl = document.getElementById("username");
const passwordEl = document.getElementById("password");

loginBtn.onclick = (e) => {
  e.preventDefault();
  loginUser();
};
registerBtn.onclick = (e) => {
  e.preventDefault();
  registerUser();
};
//loginBtn.onclick = loginUser;
//registerBtn.onclick = registerUser;
logoutBtn.onclick = logoutUser;

// UX: botón claramente “Nuevo archivo”
// statsButton.textContent = "Nuevo archivo";
statsButton.onclick = openStatsTab;
dbStatsButton.onclick = openDatabaseStatsTab;

const addTabBtn = document.getElementById("addTab");
addTabBtn.onclick = (e) => {
  e.stopPropagation();
  createTempTab();
};

window.addEventListener("DOMContentLoaded", () => {
  aceEditor = ace.edit("editor");
  aceEditor.setTheme("ace/theme/monokai");
  aceEditor.session.setMode("ace/mode/javascript");
  aceEditor.setFontSize(fontSize);

  aceEditor.session.on("change", () => {
    if (suppressChange) return;
    if (!activeTab) createTempTab();

    const tab = openTabs.get(activeTab);
    if (!tab) return;

    tab.content = aceEditor.getValue();

    if (!tab.dirty) {
      tab.dirty = true;
      markTabDirty(tab);
    }
  });

  window.addEventListener("keydown", async (e) => {
    if (e.altKey && e.key.toLowerCase() === "w") {
      e.preventDefault();
      if (!activeTab) return;

      const tab = openTabs.get(activeTab);
      if (!tab) return;

      if (tab.temporary && tab.content.trim() !== "") {
        const saveTemp = confirm(`¿Deseas guardar los cambios en "${tab.name}"?`);
        if (saveTemp) {
          const saved = await saveCurrentFile();
          if (saved === false) return;
        }
      } else if (tab.dirty) {
        // Archivo normal modificado
        const saveNormal = confirm(`¿Deseas guardar los cambios en "${tab.name}"?`);
        if (saveNormal) {
          const saved = await saveCurrentFile();
          if (saved === false) return;
        }
      }

      closeTab(activeTab, true);
    }
  });

  window.addEventListener("keydown", (e) => {
    // ===== GUARDAR ARCHIVO =====
    if (e.altKey && e.key.toLowerCase() === "s") {
      e.preventDefault();
      saveCurrentFile();
      return;
    }

    if (e.altKey && e.key.toLowerCase() === "t") {
      e.preventDefault();
      createTempTab();
      return;
    }

    // ===== ZOOM EDITOR =====
    if (!e.altKey) return;

    if (e.key === "+") fontSize++;
    if (e.key === "-") fontSize = Math.max(10, fontSize - 1);
    if (e.key === "0") fontSize = 24;

    aceEditor.setFontSize(fontSize);
    localStorage.setItem("fontSize", fontSize);
  });

  checkSession();
  setInterval(updateHardwareStatus, 1500);
});