import React, { useEffect, useState } from "react";

import BasicLoginWindow from "./LoginUI/BasicLoginWindow";
import NetworkStatusOverlay from "./Overlays/NetworkStatusOverlay";
import PerformanceMetricsOverlay from "./Overlays/PerformanceMetricsOverlay";

const IngameUI = () => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isFpsVisible, setFpsVisible] = useState(true);
  const [isNetworkStatusVisible, setNetworkStatusVisible] = useState(true);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "f") {
        setFpsVisible(!isFpsVisible);
      }
      if (event.key === "n") {
        setNetworkStatusVisible(!isNetworkStatusVisible);
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isFpsVisible, isNetworkStatusVisible]);

  return (
    <>
      <BasicLoginWindow />

      {isFpsVisible && <PerformanceMetricsOverlay />}
      {isNetworkStatusVisible && <NetworkStatusOverlay />}
    </>
  );
};

export default IngameUI;
