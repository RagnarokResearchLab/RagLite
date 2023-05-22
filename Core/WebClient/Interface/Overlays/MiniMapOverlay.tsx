import React, { useContext, useState } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";
import SharedDatabaseContext from "../SharedDatabaseContext";

import GameTooltip from "../Tooltips/GameTooltip";

const placeholderMiniMapImage = "Interface/Assets/minimap-placeholder.bmp";

const MiniMap = () => {
  const [isHovering, setIsHovering] = useState(false);
  const worldState = useContext(SharedWorldStateContext);
  const db = useContext(SharedDatabaseContext);

  if (!worldState || !db) {
    return <div>Loading...</div>;
  }

  const displayName = db[worldState.mapID] || worldState.mapID;
  const isInLoginScreen = worldState.mapID === "login_screen";
  const miniMapImageToDisplay = isInLoginScreen
    ? placeholderMiniMapImage
    : `http://localhost:9005/ui/minimap/${worldState.mapID}` + ".bmp";

  if (isInLoginScreen) return <></>;

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
        src={miniMapImageToDisplay}
        className="minimap-image"
        alt={displayName}
      />
      {isHovering && <GameTooltip>{displayName}</GameTooltip>}
    </div>
  );
};

export default MiniMap;
