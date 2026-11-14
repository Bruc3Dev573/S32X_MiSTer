# [Sega 32X](https://en.wikipedia.org/wiki/32X) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)
by [Sergey Dvodnenko](https://github.com/srg320)

[![Patreon](https://img.shields.io/website?label=patreon&logo=patreon&style=social&url=https%3A%2F%2Fwww.patreon.com%2Fsrg320%2F)](https://www.patreon.com/srg320)

## Savestates beta

This beta adds savestates to the 32X core, for 32X games and Mega Drive games. They have been tested on MiSTer hardware. If you run into a problem, please [open an issue here](https://github.com/Bruc3Dev573/S32X_MiSTer/issues), not in the official MiSTer repository.

### Installation

Copy `S32X_SS_*.rbf` from the [latest release](https://github.com/Bruc3Dev573/S32X_MiSTer/releases) to `_Console` on the SD card and start it. The official Main is enough.

### Savestates

There are four slots for each game. Press Alt+F1 through Alt+F4 to save and F1 through F4 to load. The slots are saved to `savestates/S32X` on the SD card.

On a gamepad, map the Savestate button. Hold it and press Left or Right to change slots, Mode+Down to save or Mode+Up to load. You can also save, load and choose a slot in the OSD.

F1-F3 no longer change the region and F4 no longer hides the 32X layer. Set the region in the OSD.

A state holds both Mega Drive CPUs, the sound chips, the VDP, both SH-2s, the 32X VDP and PWM, its framebuffers and SDRAM, the cartridge SRAM or EEPROM and the mapper registers. Load a state with the same game and region you saved it with.

- While a state is saved or loaded the 32X picture shows garbage for a few frames; the game redraws it.
- A save waits until every CPU can stop between bus cycles. If that doesn't happen within about three seconds, the save is dropped.
- Sega Channel cartridges that write to their ROM area (Game no Kanzume Otokuyou) keep the first 4 MB of that memory in the slot. If the game maps a bank at 4 MB or above, savestates are refused until the next reset.
- Slots saved by a version of this core with a different state layout are refused.

### Also in this build

- Virtua Racing for the Mega Drive runs with its SVP chip.
- Pier Solar runs with its mapper, its EEPROM (kept in the save file) and its protection check.
- Z80 refresh cycles no longer start a 68000 bus access (TiTAN Overdrive), and 68000 writes to work RAM no longer get a wait state (TiTAN Overdrive 2).
- The VDP FIFO lookahead index wraps at four entries, and the debug register (`C0001C`) masks planes as described in Kabuto's notes.
- FM sound: SSG-EG envelopes that end on a quiet hold go silent and the DAC offsets follow the YM2612 die, as in Nuked OPN2.

The SVP, Pier Solar, Z80, 68000 and VDP changes are also on their own branches based on the official core, without savestates.

### Building

Use Quartus Lite 17.0 to build `S32X.qpf`.

The sections below are from the upstream README and describe the original core.

## Status
* Most games are playable and run without major issues.
* Some bugs present with audio playback and graphics.
* Some features like cheats and game saves are not implemented at this time. Please don't submit an issue to request cheats or saves, this is known.

Check the issues page to see if the issue you are experiencing is already known before submitting a new issue.

## Region detection
Region detection is known to work for all commercially released 32X games except the following. These are not bugs, this is due to the way the games were developed and due to the nature of the region code system in Sega Genesis games in general:

* Shadow Squadron ~ Stellar Assault (USA, Europe) always initially boots to Europe region. The ROM header has "E" (Europe) for the region, so the developers set it to the european region, you will have to set the region manually.
* FIFA Soccer 96 (Europe) and Mortal Kombat II (Europe) boot to US/JP Region. Header has the "JUE" (Region-Free) region code, so just set your region priority.
