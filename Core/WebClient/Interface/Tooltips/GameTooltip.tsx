import React, { useEffect, useRef, useState } from "react";

interface GameTooltipProps {
  children: React.ReactNode;
}

const GameTooltip: React.FC<GameTooltipProps> = ({ children }) => {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const tooltipRef = useRef<HTMLDivElement | null>(null);

  const updateTooltipPosition = (event: MouseEvent) => {
    const tooltip = tooltipRef.current;
    if (!tooltip) return;

    let x = event.clientX;
    let y = event.clientY;

    // Adjust the tooltip position if it would go off the right or bottom of the screen
    if (x + tooltip.offsetWidth > window.innerWidth) {
      x -= tooltip.offsetWidth;
    }
    if (y + tooltip.offsetHeight > window.innerHeight) {
      y -= tooltip.offsetHeight;
    }

    setPosition({ x, y });
  };

  useEffect(() => {
    window.addEventListener("mousemove", updateTooltipPosition);

    return () => {
      window.removeEventListener("mousemove", updateTooltipPosition);
    };
  }, []);

  if (position.x == 0 && position.y == 0)
    return (
      <div
        className="game-tooltip"
        style={{
          left: `${position.x}px`,
          top: `${position.y}px`,
          visibility: "hidden",
        }}
        ref={tooltipRef}
      >
        {children}
      </div>
    );

  return (
    <div
      className="game-tooltip"
      style={{ left: `${position.x}px`, top: `${position.y}px` }}
      ref={tooltipRef}
    >
      {children}
    </div>
  );
};

export default GameTooltip;
