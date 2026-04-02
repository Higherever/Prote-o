/**
 * Electron Main Process — Equivalente ao gui/main.go
 *
 * Responsabilidades:
 * - Cria janela frameless (sem decoração nativa) — igual ao GTK3
 * - Spawna o backend Python como processo filho
 * - Aguarda o backend ficar pronto (health check)
 * - Carrega o React (dev: Vite server, prod: build estático)
 * - IPC para controle de janela (minimizar, maximizar, fechar)
 */

const { app, BrowserWindow, ipcMain } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');

let mainWindow;
let pythonProcess;

const isDev = process.env.NODE_ENV === 'development';
const PYTHON_PORT = 8000;
const VITE_PORT = 5173;

// === LOGS DE INICIALIZAÇÃO DO ELECTRON ===
console.log('=' .repeat(60));
console.log('  PROTEÇÃO GUI — ELECTRON INICIANDO');
console.log('=' .repeat(60));
console.log(`[INIT] Timestamp        : ${new Date().toISOString()}`);
console.log(`[INIT] Versão Electron  : ${process.versions.electron}`);
console.log(`[INIT] Versão Node      : ${process.versions.node}`);
console.log(`[INIT] Versão V8        : ${process.versions.v8}`);
console.log(`[INIT] Plataforma       : ${process.platform} (${process.arch})`);
console.log(`[INIT] Modo             : ${isDev ? 'DESENVOLVIMENTO (Vite)' : 'PRODUÇÃO (build estático)'}`);
console.log(`[INIT] NODE_ENV         : ${process.env.NODE_ENV || '(não definido)'}`);
console.log(`[INIT] DISPLAY          : ${process.env.DISPLAY || '(não definido)'}`);
console.log(`[INIT] WAYLAND_DISPLAY  : ${process.env.WAYLAND_DISPLAY || '(não definido)'}`);
console.log(`[INIT] XDG_SESSION_TYPE : ${process.env.XDG_SESSION_TYPE || '(não definido)'}`);
console.log(`[INIT] XDG_CURRENT_DESK : ${process.env.XDG_CURRENT_DESKTOP || '(não definido)'}`);
console.log('-'.repeat(60));

/**
 * Inicia o backend Python (FastAPI + Uvicorn)
 */
function startPythonBackend() {
  const backendPath = path.join(__dirname, '..', 'backend', 'main.py');
  
  // Verifica se existe um virtual environment (venv) configurado no backend
  const fs = require('fs');
  const venvExecutable = path.join(__dirname, '..', 'backend', 'venv', 'bin', 'python3');
  const pythonExecutable = fs.existsSync(venvExecutable) ? venvExecutable : 'python3';
  
  console.log(`[INIT] Iniciando backend Python...`);
  console.log(`[INIT] Executável  : ${pythonExecutable}`);
  console.log(`[INIT] Script      : ${backendPath}`);
  console.log(`[INIT] Porta       : ${PYTHON_PORT}`);
  
  pythonProcess = spawn(pythonExecutable, [backendPath], {
    env: { ...process.env, PROTECAO_PORT: String(PYTHON_PORT) },
    stdio: ['pipe', 'pipe', 'pipe'],
    cwd: path.join(__dirname, '..', 'backend'),
  });

  pythonProcess.stdout.on('data', (data) => {
    console.log(`[Python] ${data.toString().trim()}`);
  });

  pythonProcess.stderr.on('data', (data) => {
    console.error(`[Python] ${data.toString().trim()}`);
  });

  pythonProcess.on('close', (code) => {
    console.log(`[PYTHON] Processo encerrado com código: ${code}`);
  });

  pythonProcess.on('error', (err) => {
    console.error(`[PYTHON] Erro ao iniciar processo: ${err.message}`);
  });
}

/**
 * Aguarda o backend Python responder no health check
 */
function waitForBackend(maxRetries = 60) {
  return new Promise((resolve, reject) => {
    let retries = 0;
    const check = () => {
      const req = http.get(
        `http://127.0.0.1:${PYTHON_PORT}/api/health`,
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            console.log('[Electron] Backend Python pronto!');
            resolve();
          });
        }
      );
      req.on('error', () => {
        retries++;
        if (retries >= maxRetries) {
          reject(new Error('Backend Python não respondeu após 30 segundos'));
        } else {
          setTimeout(check, 500);
        }
      });
      req.setTimeout(1000, () => {
        req.destroy();
        retries++;
        if (retries >= maxRetries) {
          reject(new Error('Backend Python timeout'));
        } else {
          setTimeout(check, 500);
        }
      });
    };
    check();
  });
}

/**
 * Cria a janela principal — equivalente a CriarJanelaPrincipal()
 */
function createWindow() {
  console.log('[ELECTRON] Criando janela principal...');

  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    minWidth: 640,
    minHeight: 480,
    frame: false, // Frameless — igual ao SetDecorated(false) do GTK
    resizable: true,
    backgroundColor: '#3c3b46',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, '..', 'public', 'assets', 'icon.png'),
  });

  if (isDev) {
    const url = `http://localhost:${VITE_PORT}`;
    console.log(`[ELECTRON] Modo DEV — carregando Vite dev server: ${url}`);
    mainWindow.loadURL(url);
  } else {
    const filePath = path.join(__dirname, '..', 'dist', 'index.html');
    console.log(`[ELECTRON] Modo PRODUÇÃO — carregando build estático: ${filePath}`);
    mainWindow.loadFile(filePath);
  }

  mainWindow.on('closed', () => {
    console.log('[ELECTRON] Janela principal fechada.');
    mainWindow = null;
  });
}

// === IPC Handlers — Controle de janela ===
// Equivalente aos botões minimizar/maximizar/fechar do criarBarraTitulo()
ipcMain.on('window-minimize', () => {
  mainWindow?.minimize();
});

ipcMain.on('window-maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
});

ipcMain.on('window-close', () => {
  mainWindow?.close();
});

// === Lifecycle da aplicação ===
app.whenReady().then(async () => {
  console.log('[ELECTRON] App pronto. Iniciando sequência de boot...');

  // 1. Inicia o backend Python
  console.log('[BOOT] Passo 1/3 — Iniciando backend Python...');
  startPythonBackend();

  // 2. Aguarda o backend estar pronto
  console.log('[BOOT] Passo 2/3 — Aguardando backend responder...');
  try {
    await waitForBackend();
    console.log('[BOOT] Backend respondeu com sucesso!');
  } catch (e) {
    console.error('[BOOT] Falha ao iniciar backend Python:', e.message);
    // Continua mesmo sem backend — a UI pode mostrar erro
  }

  // 3. Cria a janela principal
  console.log('[BOOT] Passo 3/3 — Criando janela principal...');
  createWindow();
  console.log('[BOOT] Sequência de boot concluída. Aplicação pronta.');
  console.log('='.repeat(60));

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      console.log('[ELECTRON] Reativando janela principal...');
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  // Encerra o Python quando fechar todas as janelas
  if (pythonProcess) {
    console.log('[ELECTRON] Todas as janelas fechadas. Encerrando backend Python...');
    pythonProcess.kill('SIGTERM');
  }
  console.log('[ELECTRON] Aplicação encerrada.');
  app.quit();
});

app.on('before-quit', () => {
  if (pythonProcess) {
    pythonProcess.kill('SIGTERM');
  }
});
