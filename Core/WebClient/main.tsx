import React from "react";
import ReactDOM from "react-dom";
import { createRoot } from "react-dom/client";

import {
  ArcRotateCamera,
  Color3,
  Engine,
  HemisphericLight,
  MeshBuilder,
  MultiMaterial,
  Scene,
  StandardMaterial,
  SubMesh,
  Vector3,
} from "@babylonjs/core";

import BasicLoginWindow from "./Interface/LoginUI/BasicLoginWindow";

function CreateDemoScene() {
  const canvas = document.getElementById(
    "renderCanvas"
  ) as HTMLCanvasElement | null;

  if (!canvas) {
    throw new Error("Cannot find render canvas");
  }

  const engine = new Engine(canvas, true);

  const createScene = function () {
    const scene = new Scene(engine);

    const camera = new ArcRotateCamera(
      "camera",
      -Math.PI / 2,
      Math.PI / 4,
      10,
      new Vector3(0, 2, 0),
      scene
    );
    camera.attachControl(canvas, true);

    const light = new HemisphericLight("light", new Vector3(0, 1, 0), scene);

    const cube = MeshBuilder.CreateBox("cube", {}, scene);
    cube.subMeshes = [];
    const verticesCount = cube.getTotalVertices();

    for (let index = 0; index < 6; index++) {
      new SubMesh(index, 0, verticesCount, index * 6, 6, cube);
    }

    cube.position.y = 2.5;
    cube.material = new MultiMaterial("multi", scene);

    const materials = [
      new StandardMaterial("red", scene),
      new StandardMaterial("green", scene),
      new StandardMaterial("blue", scene),
      new StandardMaterial("yellow", scene),
      new StandardMaterial("magenta", scene),
      new StandardMaterial("cyan", scene),
    ];

    materials[0].diffuseColor = new Color3(1, 0, 0);
    materials[1].diffuseColor = new Color3(0, 1, 0);
    materials[2].diffuseColor = new Color3(0, 0, 1);
    materials[3].diffuseColor = new Color3(1, 1, 0);
    materials[4].diffuseColor = new Color3(1, 0, 1);
    materials[5].diffuseColor = new Color3(0, 1, 1);

    (cube.material as MultiMaterial).subMaterials = materials;

    scene.registerBeforeRender(() => {
      cube.rotation.x += 0.01;
      cube.rotation.y += 0.01;
      cube.rotation.z += 0.01;
    });

    return scene;
  };

  const scene = createScene();

  engine.runRenderLoop(function () {
    scene.render();
  });

  window.addEventListener("resize", function () {
    engine.resize();
  });
}

const container = document.getElementById("uiParent");
const root = createRoot(container!);
root.render(<BasicLoginWindow />);

CreateDemoScene();
