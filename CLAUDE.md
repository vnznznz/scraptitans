# Scrap Titans

Idle/clicker prototype for CrazyGames: web, portrait mobile, pixel art. Godot 4.7, GDScript.

- `docs/pitch.md`: game design, the source of truth
- `docs/plan.md`: milestones, worked in order
- `docs/tech.md`: how it's built
- `docs/web_build.md`: lightweight web export templates plan
- `docs/audio.md`: sound design, rules against annoyance, sound assignment
- `release/crazygames.md`: CrazyGames requirements and release checklist

Live on https://www.crazygames.com/game/scrap-titans, in Basic Launch (no ads yet).

## Rules

- Prototype: keep it minimal. Simplest thing that works; no speculative abstractions or extra tooling.
- Document the project's tech in `docs/tech.md`: stack, settings, structure, autoloads, data, commands, conventions. Very terse: bullets and fragments, no prose, rationale only when non-obvious. Update it in the same change as the code.
- Never run browser tests; the user does them. Verify by instrumenting Godot directly.
- Tick finished items in `docs/plan.md`.
