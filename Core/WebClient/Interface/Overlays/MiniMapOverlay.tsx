import React, { useContext, useRef, useState, useEffect } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";
import SharedDatabaseContext from "../SharedDatabaseContext";
import GameTooltip from "../Tooltips/GameTooltip";

import MapMarker from "./MapMarker";

const placeholderMiniMapImage = "Interface/Assets/minimap-placeholder.bmp";

const MiniMap = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tooltipText, setTooltipText] = useState("");
  const [showTooltip, setShowTooltip] = useState(false);
  const worldState = useContext(SharedWorldStateContext);
  const db = useContext(SharedDatabaseContext);

  if (!worldState || !db) {
    return <div>Loading...</div>;
  }

  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      const img = new Image();
      img.onload = function () {
        canvas.width = img.width;
        canvas.height = img.height;
        ctx?.drawImage(img, 0, 0, img.width, img.height);

        const imageData = ctx?.getImageData(0, 0, img.width, img.height);
        if (imageData) {
          const data = imageData.data;
          for (let i = 0; i < data.length; i += 4) {
            if (data[i] === 255 && data[i + 1] === 0 && data[i + 2] === 255) {
              data[i + 3] = 0;
            }
          }
          ctx?.putImageData(imageData, 0, 0);
        }
      };
      img.src = "http://localhost:9005/ui/minimap/" + worldState.mapID + ".bmp";
    }
  }, [worldState.mapID]);



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
    // onMouseEnter={() => setIsHovering(true)}
    // onMouseLeave={() => setIsHovering(false)}
  >
    {displayName}
  </p>
  <img
    src={miniMapImageToDisplay}
    className="minimap-image"
    alt={displayName}
  />
  <MapMarker
    x={100} // Use actual position
    y={100} // Use actual position
    width={10} // Use actual size
    height={10} // Use actual size
    onHover={() => {
		setShowTooltip(true); setTooltipText("To Prontera (prontera.rsw)")
	}
}
    onExit={() => {
		setShowTooltip(false); setTooltipText("")}
	}
  />
  {showTooltip && <GameTooltip>{tooltipText}</GameTooltip>}
</div>

  );
};

export default MiniMap;
