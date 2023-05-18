import React, { useContext, useState } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";

import GameTooltip from "../Tooltips/GameTooltip";

const MiniMap = () => {
  const [isHovering, setIsHovering] = useState(false);
  const worldState = useContext(SharedWorldStateContext);

  if (!worldState) {
    return <div>Loading...</div>;
  }

  return (
    <div id="miniMapOverlay">
      <p
        id="miniMapZoneText"
        onMouseEnter={() => setIsHovering(true)}
        onMouseLeave={() => setIsHovering(false)}
      >
        {worldState.displayName}
      </p>
      <img
        src={`Interface/Assets/minimap-placeholder.bmp`}
        className="minimap-image"
        alt={worldState.displayName}
      />
      {isHovering && <GameTooltip>{worldState.displayName}</GameTooltip>}
    </div>
  );
};

export default MiniMap;
