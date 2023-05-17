import { createContext } from "react";
import { Engine } from "@babylonjs/core";

export const SharedRenderingContext = createContext<Engine | null>(null);
