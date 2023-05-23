import { deepStrictEqual as assertEquals } from "node:assert";

import { Vector2 as Vector2D } from "@babylonjs/core";

import C_Unit, { Unit } from "../API/WorldState/C_Unit";

describe("WorldState", () => {
  describe("C_Unit", () => {
    describe("getMapPosition", () => {

		beforeAll(()=>{
			C_Unit.addKnownUnit("player", new Unit("player"))
			C_Unit.setMapPosition("player", new Vector2D(42, 123))
		})
		afterAll(()=>{
			C_Unit.removeKnownUnit("player")
		})

      it("should return null if an unknown unit ID was passed", () => {
        assertEquals(C_Unit.getMapPosition("does-not-exist"), null);
      });

      it("should return a position vector if the unit ID is known", () => {
        assertEquals(C_Unit.getMapPosition("player"), new Vector2D(42, 123));
      });
    });
  });
});
