import React from 'react';

interface Loading26Props {
  size?: number;
  color?: string;
  speed?: string;
}

const Loading26: React.FC<Loading26Props> = ({ 
  size = 180, 
  color = 'var(--color-primary)', 
  speed = '2.6s' 
}) => {
  const containerStyles: React.CSSProperties = {
    // @ts-ignore
    '--uib-size': `${size}px`,
    // @ts-ignore
    '--uib-color': color,
    // @ts-ignore
    '--uib-speed': speed,
    // @ts-ignore
    '--uib-dot-size': `calc(${size}px * 0.23)`,
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: `${size}px`,
    height: 'var(--uib-dot-size)',
    filter: 'url(#uib-jelly-ooze)',
  };

  const dotStyles: React.CSSProperties = {
    position: 'absolute',
    top: 'calc(50% - var(--uib-dot-size) / 2)',
    left: 'calc(0px - var(--uib-dot-size) / 2)',
    display: 'block',
    height: 'var(--uib-dot-size)',
    width: 'var(--uib-dot-size)',
    borderRadius: '50%',
    backgroundColor: color,
    animation: `stream ${speed} linear infinite both`,
    transition: 'background-color 0.3s ease',
  };

  return (
    <>
      <div className="loading26-container" style={containerStyles}>
        {Array.from({ length: 5 }).map((_, index) => (
          <div
            key={index}
            className="loading26-dot"
            style={{
              ...dotStyles,
              animationDelay: `calc(${speed} * ${-index * 0.2})`,
            }}
          />
        ))}
      </div>
      <svg width="0" height="0" className="loading26-svg" style={{ position: 'absolute' }}>
        <defs>
          <filter id="uib-jelly-ooze">
            <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="blur" />
            <feColorMatrix
              in="blur"
              mode="matrix"
              values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 18 -7"
              result="ooze"
            />
            <feBlend in="SourceGraphic" in2="ooze" />
          </filter>
        </defs>
      </svg>
    </>
  );
};

export default Loading26;
