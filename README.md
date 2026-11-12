# FeralPrio

A lightweight feral cat priority display for Warmane's original Wrath of the Lich King 3.3.5a client. It is based on the [Warmane feral DPS guide](https://forum.warmane.com/showthread.php?t=431156) and does not use Wrath Classic ability changes.

## Install

Download the repository ZIP, open its `FeralPrio-main` folder, and copy the **inner `FeralPrio` folder** into `Interface/AddOns`. Then restart the game or type `/reload`.

The display shows a projected sequence while in Cat Form with a living hostile target. The first icon glows when its ability is ready. A number on an icon estimates how long until it is usable or should be refreshed, based on energy, cooldown, and active timers. Tiger's Fury appears to the left of the regular action row when it is ready at low energy.

The first opener follows Mangle → Rake → build to 4–5 combo points → Savage Roar. The remaining suggestions prioritize maintaining Savage Roar, Rip, Rake, and Mangle while finding safe Ferocious Bite opportunities. Later icons are estimates; critical hits, Clearcasting, latency, and encounter mechanics can change the next action.

## Commands

- `/fp unlock` — show preview icons and drag the display
- `/fp lock` — lock its position
- `/fp size 48` — set icon size from 24 to 100
- `/fp count 3` — show 1 to 5 regular ability icons
- `/fp padding off` — hide Faerie Fire and Nature's Grasp filler suggestions
- `/fp reset` — reset the display position

This addon was written for the 3.3.5a API and has not been tested on a Wrath Classic client.

