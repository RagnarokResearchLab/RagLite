import { deepStrictEqual as assertEquals } from "node:assert";

import { Vector2 as Vector2D } from "@babylonjs/core";

import C_Unit from "../API/WorldState/C_Unit";

describe("WorldState", () => {
  describe("C_Unit", () => {
    describe("getWorldPosition", () => {
      it("should return null if an unknown unit ID was passed", () => {
        assertEquals(C_Unit.getWorldPosition("does-not-exist"), null);
      });

      it("should return a position vector if the unit ID is known", () => {
        assertEquals(C_Unit.getWorldPosition("player"), new Vector2D(0, 0));
      });
    });
  });
});
