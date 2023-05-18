import React, { createContext } from "react";

export interface WorldStateCache {
  mapID: string;
  displayName: string;
  setMapID: (mapID: string, displayName: string) => void;
}

export const SharedWorldStateContext = createContext<WorldStateCache | null>({
  mapID: "login_screen",
  displayName: "Login Screen",
  setMapID: () => {},
});

export default SharedWorldStateContext;
