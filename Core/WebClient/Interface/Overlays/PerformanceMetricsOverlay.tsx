import React, { useEffect, useContext, useState } from "react";

import { SharedRenderingContext } from "../SharedRenderingContext";

import GameTooltip from "../Tooltips/GameTooltip";

const PerformanceMetricsOverlay = () => {
  const [fps, setFps] = useState(0);
  const [isHovering, setIsHovering] = useState(false);
  const [pollingIntervalInMilliseconds, setPollingInterval] = useState(1000);

  const engine = useContext(SharedRenderingContext);

  useEffect(() => {
    const intervalId = setInterval(() => {
      setFps(engine!.getFps());
    }, pollingIntervalInMilliseconds);

    return () => clearInterval(intervalId);
  }, []);

  return (
    <div
      id="fpsCounterOverlay"
      className="fps-counter"
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
    >
      FPS: {fps.toFixed(0)}
      {isHovering && (
        <GameTooltip>
          <div>Last snapshot: {fps.toFixed(2)} FPS</div>
          <div>Polling interval: {pollingIntervalInMilliseconds} ms</div>
        </GameTooltip>
      )}
    </div>
  );
};

export default PerformanceMetricsOverlay;
