export { };

const Matter = (window as any).Matter as typeof import('matter-js');

const engine = Matter.Engine.create();

const render = Matter.Render.create({
  element: document.body,
  engine: engine,
  options: { height: 180, width: 320 },
});

const boxA = Matter.Bodies.rectangle(100, 100, 8, 8);
const boxB = Matter.Bodies.rectangle(103, 50, 8, 8);
const ground = Matter.Bodies.rectangle(160.5, 180.5, 320, 10, { isStatic: true });

Matter.Composite.add(engine.world, [boxA, boxB, ground]);

Matter.Render.run(render);

const runner = Matter.Runner.create();
Matter.Runner.run(runner, engine);




// import { Bar } from "./entities/bars.js";
// import { Bomb } from "./entities/bomb.js";
// import { Button } from "./entities/button.js";
// import { Crack } from "./entities/crack.js";
// import { Entity } from "./entities/entity.js";
// import { Key } from "./entities/key.js";
// import { Player } from "./entities/player.js";
// import { Portal } from "./entities/portal.js";
// import { Wall } from "./entities/wall.js";
// import { Camera } from "./lib/camera.js";
// import { createCanvas, runGameLoop } from "./lib/core.js";
// import { actables, drawables, players, updatables } from "./lib/data.js";
// import { loadCleanP8, MapTile } from "./lib/pico8.js";

// const WIDTH = 320;
// const HEIGHT = 180;
// const SCALE = 5;

// const ctx = createCanvas(WIDTH, HEIGHT, SCALE);
// const engine = runGameLoop();

// const game1 = await loadCleanP8('sarah/untitled_2.p8');

// const MW = game1.map[0].length * 8;
// const MH = game1.map.length * 8;

// const BOMB = game1.sprites[6];

// const camera = new Camera(MW, MH, WIDTH, HEIGHT, players);

// function createEntity(tile: MapTile, x: number, y: number) {
//   const entity = new Entity(tile.index, x * 8, y * 8, tile.sprite.image);
//   drawables.push(entity);

//   if (tile.index >= 1 && tile.index <= 3) {
//     const player = new Player(entity, camera, BOMB);
//     entity.layer = 2;
//     players.push(player);
//     updatables.push(player);
//   }
//   else if ([8, 18].includes(tile.index)) {
//     const wall = new Wall(entity);
//     actables.push(wall);
//   }
//   else if (tile.index === 4) {
//     const key = new Key(entity);
//     entity.layer = 1;
//     actables.push(key);
//     updatables.push(key);
//   }
//   else if (tile.index === 6) {
//     const bomb = new Bomb(entity);
//     entity.layer = 1;
//     actables.push(bomb);
//     updatables.push(bomb);
//   }
//   else if (tile.index === 10) {
//     const bar = new Bar(entity);
//     actables.push(bar);
//   }
//   else if (tile.index === 5) {
//     const button = new Button(entity);
//     entity.layer = 1;
//     actables.push(button);
//   }
//   else if (tile.index === 11) {
//     const portal = new Portal(entity);
//     entity.layer = 1;
//     actables.push(portal);
//   }
//   else if (tile.index === 9) {
//     const crack = new Crack(entity);
//     entity.layer = 1;
//     actables.push(crack);
//   }
// }

// for (let y = 0; y < 64; y++) {
//   for (let x = 0; x < 128; x++) {
//     const tile = game1.map[y][x];
//     if (tile.index > 0) {
//       createEntity(tile, x, y);
//     }
//   }
// }

// drawables.sort((a, b) => {
//   if (a.layer > b.layer) return 1;
//   if (a.layer < b.layer) return -1;
//   return 0;
// });

// camera.update();

// engine.update = (t) => {
//   for (const e of updatables) {
//     e.update(t);
//   }

//   ctx.reset();
//   ctx.fillStyle = '#003';
//   ctx.fillRect(0, 0, WIDTH, HEIGHT);
//   ctx.translate(camera.mx, camera.my);

//   for (const e of drawables) {
//     e.draw(ctx);
//   }

//   ctx.fillStyle = '#0038';
//   ctx.fillRect(0, 0, WIDTH, HEIGHT);
// };
