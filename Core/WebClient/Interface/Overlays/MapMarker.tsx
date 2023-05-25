import React, { FC } from "react";

interface MapMarkerProps {
  x: number;
  y: number;
  width: number;
  height: number;
  onMouseEnter: () => void;
  onMouseLeave: () => void;
}

const MapMarker: FC<MapMarkerProps> = ({ x, y, width, height, onMouseEnter, onMouseLeave }) => {
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: width,
        height: height,
		backgroundColor: 'green',
      }}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
    ></div>
  );
};

export default MapMarker;
