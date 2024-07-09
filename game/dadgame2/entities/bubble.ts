import { Actable, actables, drawables, Updatable, updatables } from "../lib/data.js";
import { removeFrom } from "../lib/helpers.js";
import { game1 } from "../main.js";
import { Entity } from "./entity.js";
import { Player } from "./player.js";

export class Bubble implements Updatable, Actable {

  sitting = false;

  constructor(public entity: Entity) { }

  actOn(player: Player, x: number, y: number) {
    if (x) {
      this.entity.x += x;
      return true;
    }

    if (y < 0) {
      this.entity.y -= 1;
      return true;
    }
    else if (y > 0) {
      // player.entity.y -= 1;
      this.sitting = true;
      this.entity.image = game1.sprites[21].image;
      return false;
    }

    return true;
  }

  update(t: number) {
    if (!this.sitting) {
      this.entity.image = game1.sprites[5].image;
    }

    this.entity.y -= this.sitting ? -0.25 : 0.25;

    if (this.entity.y < 0) {
      this.destroy();
    }

    this.sitting = false;
  }

  destroy() {
    removeFrom(actables, this);
    removeFrom(updatables, this);
    removeFrom(drawables, this.entity);
  }

}