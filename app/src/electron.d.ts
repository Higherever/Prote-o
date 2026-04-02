/**
 * electron.d.ts
 *
 * Este arquivo declara formalmente a interface `electronAPI` que é injetada
 * via preload script (app/electron/preload.js).
 * Isso permite que o TypeScript reconheça as chamadas em componentes como o TitleBar.
 */

export interface IElectronAPI {
  minimizeWindow: () => void;
  maximizeWindow: () => void;
  closeWindow: () => void;
}

declare global {
  interface Window {
    electronAPI: IElectronAPI;
  }
}
