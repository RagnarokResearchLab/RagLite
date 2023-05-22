import { deepStrictEqual as assertEquals } from "node:assert";

import C_Unit from "../API/WorldState/C_Unit";

describe('API: WorldState', () => {
describe('Namespace: C_Unit', () => {
describe('Function: getWorldPosition', () => {
  it('should return null if an unknown unit ID was passed', () => {
    assertEquals(C_Unit.getWorldPosition("does-not-exist"), null);
  });
  });
  });
});
