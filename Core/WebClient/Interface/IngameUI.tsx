import React, { useEffect, useState } from "react";

import BasicLoginWindow from "./LoginUI/BasicLoginWindow";
import PerformanceMetricsOverlay from "./Overlays/PerformanceMetricsOverlay";

const IngameUI = () => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isFpsVisible, setFpsVisible] = useState(true);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "f") {
        setFpsVisible(!isFpsVisible);
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isFpsVisible]);

  return (
    <>
      <BasicLoginWindow />

      {isFpsVisible && <PerformanceMetricsOverlay />}
    </>
  );
};

export default IngameUI;
