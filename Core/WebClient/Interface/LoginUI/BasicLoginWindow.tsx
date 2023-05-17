import React from "react";

const BasicLoginWindow = () => {
  const onWebviewShutdownRequested = () => {
    fetch("http://localhost:9009/webview/shutdown");
  };

  return (
    <div className="window" id="BasicLoginWindow">
      <div className="window-title-bar">
        <p>Connect to Realm Server</p>
      </div>
      <p className="window-content">Selected Realm: http://localhost:9005</p>
      <div className="window-footer">
        <button className="button">Connect</button>
        <button className="button" onClick={onWebviewShutdownRequested}>
          Quit
        </button>
      </div>
    </div>
  );
};

export default BasicLoginWindow;
