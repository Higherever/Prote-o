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

/**
 * Inicia o backend Python (FastAPI + Uvicorn)
 */
function startPythonBackend() {
  const backendPath = path.join(__dirname, '..', 'backend', 'main.py');
  
  // Verifica se existe um virtual environment (venv) configurado no backend
  const fs = require('fs');
  const venvExecutable = path.join(__dirname, '..', 'backend', 'venv', 'bin', 'python3');
  const pythonExecutable = fs.existsSync(venvExecutable) ? venvExecutable : 'python3';
  
  console.log(`[Electron] Iniciando backend Python via: ${pythonExecutable}`);
  
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
    console.log(`[Python] Processo encerrado com código ${code}`);
  });

  pythonProcess.on('error', (err) => {
    console.error(`[Python] Erro ao iniciar processo: ${err.message}`);
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
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    minWidth: 640,
    minHeight: 480,
    frame: false, // Frameless — igual ao SetDecorated(false) do GTK
    resizable: true,
    backgroundColor: '#f4f5f5',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, '..', 'public', 'assets', 'icon.png'),
  });

  if (isDev) {
    // Em desenvolvimento, carrega do Vite dev server
    mainWindow.loadURL(`http://localhost:${VITE_PORT}`);
    // Descomente para abrir DevTools:
    // mainWindow.webContents.openDevTools();
  } else {
    // Em produção, carrega o build estático do React
    mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }

  mainWindow.on('closed', () => {
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
  // 1. Inicia o backend Python
  startPythonBackend();

  // 2. Aguarda o backend estar pronto
  try {
    await waitForBackend();
  } catch (e) {
    console.error('[Electron] Falha ao iniciar backend Python:', e.message);
    // Continua mesmo sem backend — a UI pode mostrar erro
  }

  // 3. Cria a janela principal
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  // Encerra o Python quando fechar todas as janelas
  if (pythonProcess) {
    console.log('[Electron] Encerrando backend Python...');
    pythonProcess.kill('SIGTERM');
  }
  app.quit();
});

app.on('before-quit', () => {
  if (pythonProcess) {
    pythonProcess.kill('SIGTERM');
  }
});
