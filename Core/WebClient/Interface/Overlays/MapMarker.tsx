import React, { FC } from "react";

interface MapMarkerProps {
  x: number;
  y: number;
  width: number;
  height: number;
  onHover: () => void;
  onExit: () => void;
}

const MapMarker: FC<MapMarkerProps> = ({ x, y, width, height, onHover, onExit }) => {
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: width,
        height: height,
      }}
      onMouseEnter={onHover}
    ></div>
  );
};

export default MapMarker;
