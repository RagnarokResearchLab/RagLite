import React, { createContext } from "react";

export enum NetworkStatus {
  OK = "OK",
  TBD = "TBD",
  NYI = "NYI",
  ERR = "ERR",
}

export interface NetworkStatusCache {
  webViewRpcStatus: NetworkStatus;
  assetServerStatus: NetworkStatus;
  realmServerStatus: NetworkStatus;
  worldServerStatus: NetworkStatus;
  lastUpdatedDate: Date | null;
  set: (data: Partial<NetworkStatusCache>) => void;
}

export const SharedNetworkingContext = createContext<NetworkStatusCache | null>(
  {
    webViewRpcStatus: NetworkStatus.TBD,
    assetServerStatus: NetworkStatus.TBD,
    realmServerStatus: NetworkStatus.TBD,
    worldServerStatus: NetworkStatus.TBD,
    lastUpdatedDate: null,
    set: () => {},
  }
);

export const isInitialState = (context: NetworkStatusCache) => {
  return (
    context.webViewRpcStatus == NetworkStatus.TBD &&
    context.assetServerStatus == NetworkStatus.TBD &&
    context.realmServerStatus == NetworkStatus.TBD &&
    context.worldServerStatus == NetworkStatus.TBD
  );
};

export const isErrorState = (context: NetworkStatusCache) => {
  return [
    context.webViewRpcStatus,
    context.assetServerStatus,
    context.realmServerStatus,
    context.worldServerStatus,
  ].includes(NetworkStatus.ERR);
};
export default SharedNetworkingContext;
