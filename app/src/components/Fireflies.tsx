/**
 * Fireflies — Equivalente ao gui/ui/fireflies.go
 *
 * Motor de animação de vagalumes usando Canvas HTML5.
 * Porta direta da lógica Cairo do Go para Canvas API do browser.
 *
 * Características portadas:
 * - 40 vagalumes azuis (rgba 37, 99, 235) — mesma cor do fireflies.go
 * - Movimento orgânico com velocidade lenta
 * - Pulsação de opacidade (0.05 a 0.5)
 * - Wrap-around nas bordas
 * - Halo externo mais suave (opacidade * 0.3)
 * - ~30 FPS via requestAnimationFrame
 * - Responsivo: acompanha redimensionamento da janela
 */

import { useRef, useEffect } from 'react';

interface Vagalume {
  x: number;
  y: number;
  vx: number;
  vy: number;
  raio: number;
  opacidade: number;
  opacDir: number;
}

interface FirefliesProps {
  quantidade?: number;
}

export default function Fireflies({ quantidade = 40 }: FirefliesProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const vagalumesRef = useRef<Vagalume[]>([]);
  const animFrameRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Ajusta tamanho do canvas ao container
    const resizeCanvas = () => {
      const parent = canvas.parentElement;
      if (parent) {
        canvas.width = parent.clientWidth;
        canvas.height = parent.clientHeight;
      }
    };

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    // Inicializa vagalumes — equivalente a NovoMotorVagalumes()
    if (vagalumesRef.current.length === 0) {
      vagalumesRef.current = Array.from({ length: quantidade }, () => ({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 0.8,
        vy: (Math.random() - 0.5) * 0.8,
        raio: 1.5 + Math.random() * 2.5,
        opacidade: 0.1 + Math.random() * 0.4,
        opacDir: 1.0,
      }));
    }

    // Atualizar posição — equivalente a (m *MotorVagalumes) atualizar()
    const atualizar = () => {
      const w = canvas.width;
      const h = canvas.height;

      for (const v of vagalumesRef.current) {
        // Move o vagalume
        v.x += v.vx;
        v.y += v.vy;

        // Recalcula direção aleatoriamente (movimento orgânico)
        v.vx += (Math.random() - 0.5) * 0.1;
        v.vy += (Math.random() - 0.5) * 0.1;

        // Limita velocidade máxima
        const maxVel = 1.0;
        v.vx = Math.max(-maxVel, Math.min(maxVel, v.vx));
        v.vy = Math.max(-maxVel, Math.min(maxVel, v.vy));

        // Wrap around — mantém dentro da janela
        if (v.x < 0) v.x = w;
        else if (v.x > w) v.x = 0;
        if (v.y < 0) v.y = h;
        else if (v.y > h) v.y = 0;

        // Pulsa a opacidade suavemente
        v.opacidade += v.opacDir * 0.005;
        if (v.opacidade >= 0.5) v.opacDir = -1.0;
        else if (v.opacidade <= 0.05) v.opacDir = 1.0;
      }
    };

    // Desenhar — equivalente a (m *MotorVagalumes) desenhar()
    const desenhar = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      for (const v of vagalumesRef.current) {
        // Cor azul (#2563eb) com opacidade — mesma do fireflies.go
        // rgba(37, 99, 235, opacidade)

        // Círculo principal
        ctx.beginPath();
        ctx.arc(v.x, v.y, v.raio, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(37, 99, 235, ${v.opacidade})`;
        ctx.fill();

        // Halo externo mais suave — opacidade * 0.3
        ctx.beginPath();
        ctx.arc(v.x, v.y, v.raio * 2.5, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(37, 99, 235, ${v.opacidade * 0.3})`;
        ctx.fill();
      }
    };

    // Loop de animação ~30 FPS equivalente a glib.TimeoutAdd(33, ...)
    let lastTime = 0;
    const FRAME_INTERVAL = 33; // ~30 FPS

    const loop = (currentTime: number) => {
      animFrameRef.current = requestAnimationFrame(loop);

      // Throttle para ~30 FPS como no Go
      if (currentTime - lastTime < FRAME_INTERVAL) return;
      lastTime = currentTime;

      atualizar();
      desenhar();
    };

    animFrameRef.current = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(animFrameRef.current);
      window.removeEventListener('resize', resizeCanvas);
    };
  }, [quantidade]);

  return (
    <canvas
      ref={canvasRef}
      className="canvas-vagalumes"
      id="canvas-vagalumes"
    />
  );
}
