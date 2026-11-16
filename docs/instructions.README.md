# CatchNRun

You are implementing the first runnable prototype of the CatchNRun Godot project.

## 1. Read the Documentation First

Before modifying any code:

1. Read the root README.md.
2. Follow its references and read the relevant Markdown specifications under docs/.
3. Read docs/project_architecture.README.md carefully.
4. Inspect the existing Godot project and repository.

The documentation is the source of truth.

The repository already contains experimental/conceptual code. Reuse it where helpful, but you may restructure, replace, or remove it when it conflicts with the documented architecture or makes the prototype unnecessarily complicated.

Before implementation, briefly summarize:

- your understanding of the game,
- the existing implementation,
- what you will reuse,
- what you will replace,
- and your implementation plan.

Then proceed with the implementation.

## 2. Current Goal

Do **not** try to implement the complete game.

Build the smallest runnable, multiplayer-capable and highly testable technical skeleton.

The first milestone should establish:

- runnable Godot project,
- local host,
- clients joining through localhost,
- minimal lobby,
- Hunter / Runner role assignment,
- synchronized player spawning,
- synchronized basic movement,
- match start,
- Runner preparation phase,
- delayed Hunter spawn,
- sandbox / god-mode environment,
- bot clients for multiplayer testing,
- repeatable multiplayer smoke testing.

Advanced gameplay systems documented under docs/ should be implemented later unless a minimal stub is needed for the prototype.

## 3. Keep the Prototype Visually Minimal

Do not create final assets.

Use simple placeholders.

For example:

Runner

-> icon.svg

-> blue

Hunter

-> icon.svg

-> red

Wall

-> rectangle

Tower

-> triangle

Crystal Mine

-> circle

Use simple matching collision shapes.

The technical structure matters more than appearance.

## 4. Prioritize Testability

Testability is a core requirement, not an optional later feature.

Create a dedicated development sandbox.

From the sandbox I should be able to quickly:

- start a local host,
- add Runner bots,
- add a Hunter bot,
- start the match,
- skip the Runner preparation timer,
- reset the match,
- inspect connected peers,
- inspect assigned teams and match state.

Simple debug buttons and labels are sufficient.

I want to be able to start common test scenarios with one or very few actions.

For example:

Start Host + 1 Hunter Bot + 2 Runner Bots

Bots do not need gameplay intelligence yet.

They initially only need to:

- connect as real multiplayer peers where practical,
- register,
- receive a role,
- spawn,
- move using deterministic/simple behavior,
- remain connected,
- disconnect correctly.

The purpose of bots at this stage is primarily to test networking and synchronization.

## 5. Implementation Order

Implement incrementally:

1. Inspect documentation and existing project

2. Make project reliably runnable

3. Offline Hunter + Runner placeholders

4. Host / client networking

5. Minimal lobby and role assignment

6. Multiplayer spawning and movement

7. Match lifecycle

8. Sandbox

9. Bot clients

10. Automated multiplayer smoke test

After each step, run and validate the project before continuing.

Do not build later gameplay systems prematurely.

## 6. Architecture

Follow docs/project_architecture.README.md.

In particular:

- Keep scenes, scripts, and feature-specific resources together.
- Prefer composition over deep inheritance.
- Connect signals explicitly in code.
- Keep gameplay logic outside UI.
- Keep authoritative gameplay state independent from presentation.
- Keep configuration close to the feature that owns it.
- Use the host/server as the authority for multiplayer state.
- Clients should send intent rather than directly modifying authoritative state.

Do not introduce abstractions purely for hypothetical future requirements.

## 7. First Milestone Definition of Done

The prototype is successful when:

- the project starts without errors,
- a host can create a game,
- clients can join locally,
- players appear in a minimal lobby,
- Hunter and Runner roles are assigned,
- the host can start the match,
- Runners spawn,
- the Hunter spawns after the preparation phase,
- Hunter and Runner placeholders are visually distinguishable,
- basic movement synchronizes between peers,
- the sandbox can populate a test game with bots,
- bots successfully connect and participate as multiplayer peers,
- the sandbox can quickly start/reset test scenarios,
- a repeatable multiplayer smoke test exists,
- important networking and match transitions are logged.

Do not proceed into full economy, construction, combat, fog of war, minimap, shop, or polished UI implementation just because these systems are documented.

Once this milestone is working reliably, stop and summarize:

- what was implemented,
- what existing code was reused or replaced,
- how to start the sandbox,
- how to host and join,
- how to populate with bots,
- how to run the multiplayer smoke test,
- known limitations,
- recommended next milestone.