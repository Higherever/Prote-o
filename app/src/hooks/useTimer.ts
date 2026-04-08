/**
 * useTimer — Hook de cronômetro reutilizável
 *
 * Fornece um cronômetro que conta segundos decorridos.
 * Usado para medir tempo total de instalação e tempo por etapa.
 */

import { useState, useRef, useCallback, useEffect } from 'react';

export function useTimer() {
  const [elapsed, setElapsed] = useState(0);
  const intervalRef = useRef<number | undefined>(undefined);
  const startTimeRef = useRef<number>(0);

  const start = useCallback(() => {
    // BUG-06: limpar intervalo anterior antes de iniciar novo para evitar memory leak
    if (intervalRef.current !== undefined) {
      clearInterval(intervalRef.current);
    }
    startTimeRef.current = Date.now() - elapsed * 1000;
    intervalRef.current = window.setInterval(() => {
      setElapsed(Math.floor((Date.now() - startTimeRef.current) / 1000));
    }, 1000);
  }, [elapsed]);

  const stop = useCallback(() => {
    if (intervalRef.current !== undefined) {
      clearInterval(intervalRef.current);
      intervalRef.current = undefined;
    }
  }, []);

  const reset = useCallback(() => {
    stop();
    setElapsed(0);
  }, [stop]);

  /** Formata elapsed em M:SS */
  const formatted = `${Math.floor(elapsed / 60)}:${String(elapsed % 60).padStart(2, '0')}`;

  // Cleanup ao desmontar
  useEffect(() => () => stop(), [stop]);

  return { elapsed, formatted, start, stop, reset };
}
