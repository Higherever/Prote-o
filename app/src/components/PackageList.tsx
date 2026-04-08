/**
 * PackageList — Lista visual de pacotes sendo instalados
 *
 * Cada pacote exibe:
 * - Ícone de status (⏳ aguardando, ⬇️ instalando, ✅ concluído, ❌ erro)
 * - Nome do pacote
 * - Tempo decorrido (se aplicável)
 *
 * Animações de entrada por item (fadeInUp staggered).
 */

import type { PacoteInfo } from '../hooks/useWebSocket';

interface PackageListProps {
  pacotes: PacoteInfo[];
}

const iconeStatus: Record<string, string> = {
  aguardando: '⏳',
  instalando: '⬇️',
  concluido: '✅',
  erro: '❌',
};

function formatarTempo(inicio?: number, fim?: number): string {
  if (!inicio) return '';
  const agora = fim || Date.now() / 1000;
  const seg = Math.max(0, Math.floor(agora - inicio));
  return `${Math.floor(seg / 60)}:${String(seg % 60).padStart(2, '0')}`;
}

export default function PackageList({ pacotes }: PackageListProps) {
  if (pacotes.length === 0) return null;

  return (
    <div className="package-list" id="package-list">
      {pacotes.map((pkg, i) => (
        <div
          key={`${pkg.nome}-${i}`}
          className={`package-item package-${pkg.status}`}
          style={{ animationDelay: `${i * 0.05}s` }}
        >
          <span className="package-icon">{iconeStatus[pkg.status]}</span>
          <span className="package-nome">{pkg.nome}</span>
          {(pkg.status === 'instalando' || pkg.status === 'concluido') && (
            <span className="package-tempo">
              ⏱ {formatarTempo(pkg.tempoInicio, pkg.tempoFim)}
            </span>
          )}
        </div>
      ))}
    </div>
  );
}
