import React, { useState, useEffect } from "react";

import IngameUI from "./IngameUI";

import SharedDatabaseContext, { DatabaseCache } from "./SharedDatabaseContext";
import SharedNetworkingContext, {
  NetworkStatusCache,
  NetworkStatus,
} from "./SharedNetworkingContext";
import SharedWorldStateContext, {
  WorldStateCache,
} from "./SharedWorldStateContext";

function WebClient() {
  const [db, setDb] = useState<DatabaseCache>({});
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

  const [world, setWorld] = useState<WorldStateCache>({
    mapID: "login_screen",
    displayName: "Login Screen",
    setMapID: (mapID: string) => {
      const displayName = db[mapID] || mapID;
      setWorld((oldWorld) => ({ ...oldWorld, mapID, displayName }));
    },
  });

  useEffect(() => {
    const fetchDisplayNames = async () => {
      try {
        const response = await fetch(
          "http://localhost:9005/DB/map-display-names.json"
        );
        const data = await response.json();
        setDb(data);
      } catch (error) {
        console.error("Failed to fetch display names:", error);
      }
    };

    fetchDisplayNames();
  }, []);

  return (
    <SharedDatabaseContext.Provider value={db}>
      <SharedNetworkingContext.Provider value={cache}>
        <SharedWorldStateContext.Provider value={world}>
          <IngameUI />
        </SharedWorldStateContext.Provider>
      </SharedNetworkingContext.Provider>
    </SharedDatabaseContext.Provider>
  );
}

export default WebClient;
