import React, { useContext, useState, useEffect } from "react";
import formatDistanceToNow from "date-fns/formatDistanceToNow";

import GameTooltip from "../Tooltips/GameTooltip";
import SharedNetworkingContext, {
  isErrorState,
  isInitialState,
  NetworkStatus,
} from "../SharedNetworkingContext";

const NetworkStatusOverlay = () => {
  const [isHovering, setIsHovering] = useState(false);
  const [lastUpdatedDate, setlastUpdatedDate] = useState<Date | null>(null);
  const networkingStatusCache = useContext(SharedNetworkingContext);

  let networkStatus = NetworkStatus.TBD;

  if (!networkingStatusCache) {
    return (
      <div
        id="networkStatusOverlay"
        className={`network-status ${networkStatus}`}
      >
        Loading Shared Networking Context ...
      </div>
    );
  }

  if (!isInitialState(networkingStatusCache))
    networkStatus = isErrorState(networkingStatusCache)
      ? NetworkStatus.ERR
      : NetworkStatus.OK;

  const urls: Record<string, string> = {
    webViewRpcStatus: "http://localhost:9009/webview/ping",
    assetServerStatus: "http://localhost:9005/data/clientinfo.xml",
    realmServerStatus: "http://localhost:9004/realms/",
    worldServerStatus: "http://localhost:9009/webview/ping", // Replace with WebSocket ping later
  };

  const checkStatus = async (url: string, statusKey: string) => {
    try {
      const response = await fetch(url);
      if (response.ok) {
        networkingStatusCache.set({ [statusKey]: NetworkStatus.OK });
      } else {
        networkingStatusCache.set({ [statusKey]: NetworkStatus.ERR });
      }
    } catch (error) {
      networkingStatusCache.set({ [statusKey]: NetworkStatus.ERR });
    }
  };

  const onClick = () => {
    for (const [statusKey, url] of Object.entries(urls)) {
      checkStatus(url, statusKey);
    }
    networkingStatusCache.set({ lastUpdatedDate: new Date() });
  };

  // Runs whenever the component is mounted
  useEffect(() => {
    onClick();
  }, []);

  return (
    <div
      id="networkStatusOverlay"
      className={`network-status ${networkStatus}`}
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
      onClick={onClick}
    >
      <div>Network Status: {networkStatus}</div>
      {isHovering && (
        <GameTooltip>
          <div>
            Last Update:{" "}
            {networkingStatusCache.lastUpdatedDate
              ? `${formatDistanceToNow(
                  networkingStatusCache.lastUpdatedDate
                )} ago`
              : "Never"}
          </div>
          <div>Click to manually update (will send network requests)</div>

          <hr />

          <div className="networking-status-line">
            <span
              className={`networking-status-icon ${networkingStatusCache.webViewRpcStatus}`}
            ></span>
            WebView RPC - http://localhost:9009/webview
          </div>
          <div className="networking-status-line">
            <span
              className={`networking-status-icon ${networkingStatusCache.assetServerStatus}`}
            ></span>
            Asset Server - http://localhost:9005
          </div>
          <div className="networking-status-line">
            <span
              className={`networking-status-icon ${networkingStatusCache.realmServerStatus}`}
            ></span>
            Realm Server - http://localhost:9004
          </div>
          <div className="networking-status-line">
            <span
              className={`networking-status-icon ${networkingStatusCache.worldServerStatus}`}
            ></span>
            World Server - ws://localhost:9001
          </div>
        </GameTooltip>
      )}
    </div>
  );
};

export default NetworkStatusOverlay;
