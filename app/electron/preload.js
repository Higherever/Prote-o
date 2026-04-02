/**
 * Electron Preload Script
 *
 * Expõe uma API segura via contextBridge para o React controlar a janela.
 * Equivalente aos botões de minimizar/maximizar/fechar do criarBarraTitulo() em window.go.
 */

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  /**
   * Minimiza a janela — equivalente a win.Iconify()
   */
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  /**
   * Alterna maximizar/restaurar — equivalente a win.Maximize()/win.Unmaximize()
   */
  maximizeWindow: () => ipcRenderer.send('window-maximize'),

  /**
   * Fecha a janela — equivalente a win.Close()
   */
  closeWindow: () => ipcRenderer.send('window-close'),
});
