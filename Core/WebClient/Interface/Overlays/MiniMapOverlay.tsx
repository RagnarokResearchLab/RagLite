import React, { useContext, useState } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";
import SharedDatabaseContext from "../SharedDatabaseContext";

import GameTooltip from "../Tooltips/GameTooltip";

const MiniMap = () => {
  const [isHovering, setIsHovering] = useState(false);
  const worldState = useContext(SharedWorldStateContext);
  const db = useContext(SharedDatabaseContext);

  if (!worldState || !db) {
    return <div>Loading...</div>;
  }

  const displayName = db[worldState.mapID] || worldState.mapID;

  return (
    <div id="miniMapOverlay">
      <p
        id="miniMapZoneText"
        onMouseEnter={() => setIsHovering(true)}
        onMouseLeave={() => setIsHovering(false)}
      >
        {displayName}
      </p>
      <img
        src={`Interface/Assets/minimap-placeholder.bmp`}
        className="minimap-image"
        alt={displayName}
      />
      {isHovering && <GameTooltip>{displayName}</GameTooltip>}
    </div>
  );
};

export default MiniMap;
