/**
 * ProgressHeader — Cabeçalho da tela de progresso
 *
 * Exibe:
 * - Nome da etapa atual
 * - Indicador "Etapa N/Total"
 * - Cronômetro da etapa
 * - Barra de progresso com gradient animado
 */

interface ProgressHeaderProps {
  etapa: string;
  numero: number;
  total: number;
  tempoEtapa: string;
}

export default function ProgressHeader({
  etapa,
  numero,
  total,
  tempoEtapa,
}: ProgressHeaderProps) {
  const porcentagem = total > 0 ? Math.round((numero / total) * 100) : 0;

  return (
    <div className="progress-header" id="progress-header">
      <div className="progress-header-info">
        <span className="progress-etapa-label">
          Etapa {numero}/{total}
        </span>
        <span className="progress-etapa-nome">{etapa}</span>
        <span className="progress-etapa-timer">⏱ {tempoEtapa}</span>
      </div>

      <div className="barra-progresso-container">
        <div
          className="barra-progresso-fill"
          style={{ width: `${porcentagem}%` }}
        />
      </div>

      <span className="progress-porcentagem">{porcentagem}%</span>
    </div>
  );
}
