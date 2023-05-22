import React, { useContext, useEffect, useState } from "react";
import SharedWorldStateContext from "../SharedWorldStateContext";
import SharedDatabaseContext from "../SharedDatabaseContext";

const DebugMenuOverlay = () => {
  const worldState = useContext(SharedWorldStateContext);
  const db = useContext(SharedDatabaseContext);
  const [worlds, setWorlds] = useState<string[]>([]);
  const [searchTerm, setSearchTerm] = useState<string>("");
  const [loaded, setLoaded] = useState(false);

  if (!worldState || !db) {
    return <>Loading...</>;
  }

  useEffect(() => {
    setLoaded(true);
  }, []);

  useEffect(() => {
    const fetchWorlds = async () => {
      try {
        const response = await fetch(
          "http://localhost:9005/DB/maps-autogenerated.json"
        );
        const data = await response.json();
        setWorlds(data);
      } catch (error) {
        console.error("Failed to fetch worlds:", error);
      }
    };

    fetchWorlds();
  }, []);

  const onClick = (mapID: string) => {
    worldState.setMapID(mapID);
  };

  const onKeydown = (event: React.KeyboardEvent) => {
    if (event.key === "Escape") {
      setSearchTerm("");
    }
  };

  const filteredWorlds = searchTerm
    ? worlds.filter(
        (mapID) =>
          mapID.toLowerCase().includes(searchTerm.toLowerCase()) ||
          (db[mapID] &&
            db[mapID].toLowerCase().includes(searchTerm.toLowerCase()))
      )
    : worlds;

  return (
    <div className={`debug-menu ${loaded ? "loaded" : ""}`}>
      <fieldset>
        <legend>Force map change</legend>
        <input
          type="text"
          placeholder="Search..."
          value={searchTerm}
          onChange={(event) => setSearchTerm(event.target.value)}
          onKeyDown={onKeydown}
        />
        <hr />
        <p>
          Showing {filteredWorlds.length} out of {worlds.length} maps
        </p>
        <hr />
        {filteredWorlds.length === 0 && <p>No matches for "{searchTerm}"</p>}
        <div className="debug-menu-buttons">
          {filteredWorlds.map((mapID, index) => (
            <div key={index}>
              <button onClick={() => onClick(mapID)}>
                {db[mapID] || mapID}
              </button>
            </div>
          ))}
        </div>
      </fieldset>
    </div>
  );
};

export default DebugMenuOverlay;
