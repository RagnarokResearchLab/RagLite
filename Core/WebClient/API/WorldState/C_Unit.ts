import { Vector2 as Vector2D } from "@babylonjs/core";

class Unit {
  unitID : string;
  mapPosition: Vector2D;
  // worldPosition: Vector3D;
}

const C_Unit = {
  knownUnits: {} as Record<string, Unit>,
  getWorldPosition: (unitID: string): Vector2D | null => {
	const unit = C_Unit.knownUnits[unitID];

	if(!unit) return null;

	return new Vector2D(0, 0); // TODO replace with actual unit position
  },
} as const;

export default C_Unit;
