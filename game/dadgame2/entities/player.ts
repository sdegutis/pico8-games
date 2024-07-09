import { B, X } from "../lib/core.js";
import { actables, players, Updatable } from "../lib/data.js";
import { intersects } from "../lib/helpers.js";
import { Entity } from "./entity.js";

export class Player implements Updatable {

  gamepadIndex = players.length;
  get gamepad() { return navigator.getGamepads()[this.gamepadIndex]; }

  xvel = 0;
  yvel = 0;

  stoodFor = 0;

  constructor(public entity: Entity) {
  }

  update(t: number) {
    this.move();

    if (this.gamepad?.buttons[B].pressed && this.stoodFor >= 1) {
      this.stoodFor = 0;
      this.yvel = -5.15;
    }
  }

  move() {
    let x1 = 0;
    if (this.gamepad) {
      [x1] = this.gamepad.axes;
    }

    const movingx = ~~(x1 * 100) / 100;
    const xspeed = 1;
    const xmaxspeed = 2;

    if (movingx) {
      // accel
      this.xvel += x1 * xspeed;
      if (this.xvel > xmaxspeed) this.xvel = xmaxspeed;
      if (this.xvel < -xmaxspeed) this.xvel = -xmaxspeed;
    }
    else {
      // decel
      if (this.xvel > 0) {
        this.xvel -= xspeed;
        if (this.xvel < 0) this.xvel = 0;
      }
      else if (this.xvel < 0) {
        this.xvel += xspeed;
        if (this.xvel > 0) this.xvel = 0;
      }
    }

    if (this.xvel) {
      const dir = Math.sign(this.xvel);
      const max = Math.abs(this.xvel);
      for (let i = 0; i < max; i += 1) {
        this.entity.x += dir;
        const touching = actables.filter(a => intersects(a.entity, this.entity));
        if (!touching.every(a => a.actOn(this, dir, 0))) {
          this.entity.x -= dir;
          this.xvel = 0;
          break;
        }
      }
    }

    const yspeed = 0.5;
    const ymaxspeed = 7;

    this.yvel += yspeed;
    if (this.yvel > ymaxspeed) this.yvel = ymaxspeed;

    if (this.yvel) {
      const dir = Math.sign(this.yvel);
      const max = Math.abs(this.yvel);
      let broke = false;
      for (let i = 0; i < max; i += 1) {
        this.entity.y += dir;
        const touching = actables.filter(a => intersects(a.entity, this.entity));
        if (!touching.every(a => a.actOn(this, 0, dir))) {
          this.entity.y -= dir;

          if (this.yvel > 0) {
            this.stoodFor++;
          }

          this.yvel = 0;
          broke = true;
          break;
        }
      }
      if (!broke && this.yvel > 0) {
        this.stoodFor = 0;
      }
    }
  }

  rumble(sec: number, weak: number, strong: number) {
    // this.gamepad!.vibrationActuator.playEffect("dual-rumble", {
    //   startDelay: 0,
    //   duration: sec * 1000,
    //   weakMagnitude: weak,
    //   strongMagnitude: strong,
    // });
  }

}