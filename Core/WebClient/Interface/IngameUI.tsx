import React, { useEffect, useState, useCallback } from "react";

import BasicLoginWindow from "./LoginUI/BasicLoginWindow";
import DebugMenuOverlay from "./Overlays/DebugMenuOverlay";
import MiniMapOverlay from "./Overlays/MiniMapOverlay";
import NetworkStatusOverlay from "./Overlays/NetworkStatusOverlay";
import PerformanceMetricsOverlay from "./Overlays/PerformanceMetricsOverlay";

const IngameUI = () => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isFpsVisible, setFpsVisible] = useState(true);
  const [isNetworkStatusVisible, setNetworkStatusVisible] = useState(true);
  const [isMiniMapVisible, setMiniMapVisibilityStatus] = useState(true);
  const [isDebugMenuVisible, setDebugMenuVisibility] = useState(true);

  const handleKeyDown = useCallback((event: KeyboardEvent) => {
    if (event.target instanceof HTMLInputElement) {
      return;
    }

    if (event.key === "f") {
      setFpsVisible((prev) => !prev);
    }
    if (event.key === "n") {
      setNetworkStatusVisible((prev) => !prev);
    }
    if (event.key === "m") {
      setMiniMapVisibilityStatus((prev) => !prev);
    }
    if (event.key === "d") {
      setDebugMenuVisibility((prev) => !prev);
    }
  }, []);

  useEffect(() => {
    document.addEventListener("keydown", handleKeyDown);

    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [handleKeyDown]);

  return (
    <>
      <BasicLoginWindow />

      {isFpsVisible && <PerformanceMetricsOverlay />}
      {isNetworkStatusVisible && <NetworkStatusOverlay />}
      {isMiniMapVisible && <MiniMapOverlay />}
      {isDebugMenuVisible && <DebugMenuOverlay />}
    </>
  );
};

export default IngameUI;
