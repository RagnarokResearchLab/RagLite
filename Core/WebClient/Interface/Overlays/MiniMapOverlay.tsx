import React, { useContext } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";

const MiniMap = () => {
  const worldState = useContext(SharedWorldStateContext);

  if (!worldState) {
    return <div>Loading...</div>;
  }

  return (
    <div id="miniMapOverlay">
      <p id="miniMapZoneText">
        {worldState.displayName} ({worldState.mapID})
      </p>
      <img
        src={`Interface/Assets/minimap-placeholder.bmp`}
        className="minimap-image"
        alt={worldState.displayName}
      />
    </div>
  );
};

export default MiniMap;
