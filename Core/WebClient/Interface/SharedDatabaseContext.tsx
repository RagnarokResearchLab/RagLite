import React, { createContext } from "react";

export interface DatabaseCache {
  [mapID: string]: string;
}

export const SharedDatabaseContext = createContext<DatabaseCache | null>(null);

export default SharedDatabaseContext;
