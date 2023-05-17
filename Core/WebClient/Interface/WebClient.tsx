import React, { useState } from "react";

import IngameUI from "./IngameUI";

import SharedNetworkingContext, {
  NetworkStatusCache,
  NetworkStatus,
} from "./SharedNetworkingContext";

function WebClient() {
  const [cache, updateCacheEntry] = useState<NetworkStatusCache>({
    webViewRpcStatus: NetworkStatus.TBD,
    assetServerStatus: NetworkStatus.TBD,
    realmServerStatus: NetworkStatus.TBD,
    worldServerStatus: NetworkStatus.TBD,
    lastUpdatedDate: null,
    set: (updatedEntry: Partial<NetworkStatusCache>) => {
      updateCacheEntry((existingEntries) => ({
        ...existingEntries,
        ...updatedEntry,
      }));
    },
  });

  return (
    <SharedNetworkingContext.Provider value={cache}>
      <IngameUI />
    </SharedNetworkingContext.Provider>
  );
}

export default WebClient;
