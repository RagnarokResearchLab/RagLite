function CreateDemoScene() {
		const canvas = document.getElementById('renderCanvas');
		const engine = new BABYLON.Engine(canvas, true);

		const createScene = function () {
			const scene = new BABYLON.Scene(engine);

			const camera = new BABYLON.ArcRotateCamera('camera', -Math.PI / 2, Math.PI / 4, 10, new BABYLON.Vector3(0, 2, 0), scene);
			camera.attachControl(canvas, true);

			const light = new BABYLON.HemisphericLight('light', new BABYLON.Vector3(0, 1, 0), scene);

			const materials = [
				new BABYLON.StandardMaterial('red', scene),
				new BABYLON.StandardMaterial('green', scene),
				new BABYLON.StandardMaterial('blue', scene),
				new BABYLON.StandardMaterial('yellow', scene),
				new BABYLON.StandardMaterial('magenta', scene),
				new BABYLON.StandardMaterial('cyan', scene),
			];

			materials[0].diffuseColor = new BABYLON.Color3(1, 0, 0);
        materials[1].diffuseColor = new BABYLON.Color3(0, 1, 0);
        materials[2].diffuseColor = new BABYLON.Color3(0, 0, 1);
        materials[3].diffuseColor = new BABYLON.Color3(1, 1, 0);
        materials[4].diffuseColor = new BABYLON.Color3(1, 0, 1);
        materials[5].diffuseColor = new BABYLON.Color3(0, 1, 1);

        const cube = BABYLON.MeshBuilder.CreateBox('cube', {}, scene);
        cube.subMeshes = [];
        const verticesCount = cube.getTotalVertices();

        for (let index = 0; index < 6; index++) {
			new BABYLON.SubMesh(index, 0, verticesCount, index * 6, 6, cube);
        }

        cube.material = new BABYLON.MultiMaterial('multi', scene);
        cube.material.subMaterials = materials;

        const scale = 0.005;
        const MeshWriter = BABYLON.MeshWriter(scene, { scale: scale, defaultFont: "Arial" });
        const textOptions = {
			anchor: "center",
            letter_height: 1,
            color: "#1C3870",
            position: {
				x: 0,
                y: 2.5
            }
        };
        const text = new MeshWriter("Hello WebGL!", textOptions);
		const textMesh = text.getMesh();
		textMesh.rotate(new BABYLON.Vector3(1, 0, 0), -45);

        scene.registerBeforeRender(() => {
			cube.rotation.x += 0.01;
            cube.rotation.y += 0.01;
            cube.rotation.z += 0.01;

			textMesh.position.y = 2.5 + (Math.sin(Date.now() * 0.002) * 0.5);

            text.getMesh().rotation.y = camera.alpha;


        });

        return scene;
    };

    const scene = createScene();

    engine.runRenderLoop(function () {
		scene.render();
    });

    window.addEventListener('resize', function () {
		engine.resize();
    });
}

export { CreateDemoScene };