# Pollinations NPC for Roblox

Give any NPC a conversation, in a few lines of Luau, backed by
[Pollinations](https://pollinations.ai) text models.

![Made with Pollinations](media/badge-made-with.svg)

## The part that matters: dialogue that can act

Most NPC wrappers stop at chat. This one also lets a character *do* something
in your game.

The important detail is who is in charge. The language model is **never**
allowed to decide that an action happens. You register a whitelist of action
types, the model may only *propose* one of them, and your own handler decides
whether it actually runs:

```lua
local npc = PollinationsNpc.start({
    name = "Gatekeeper Mara",
    persona = "You are Gatekeeper Mara. You guard the north gate.",
    actions = {
        open_gate = function(action, context)
            if gateOpen then
                return false -- refuse, whatever the model asked for
            end
            if (context.player.Character.HumanoidRootPart.Position - gate.Position).Magnitude > 40 then
                return false -- too far away to matter
            end
            openTheGate()
            return true
        end,
    },
})
```

Your handler returns `true` only when it really performed the action. Anything
it returns `false` for, or throws on, simply does not happen.

That separation is deliberate. On a plain `nova-fast` turn, a model asked to
gatekeep will cheerfully "open the gate" for a blunt demand if you let it make
the call. Policy belongs to the game.

## Install

1. Copy `src/` into your place as a **Folder** named `PollinationsNpc` under
   `ServerScriptService`. Everything here runs server-side.
2. In **Game Settings > Security**, tick **Allow HTTP Requests**.
3. Create a secret named `POLLINATIONS_API_KEY` in **Game Settings >
   Security > Secrets**, using a key from
   [enter.pollinations.ai/keys](https://enter.pollinations.ai/keys).
4. Call `PollinationsNpc.start` from a server Script.

For a quick local test before a secret exists, set a String attribute
`PollinationsApiKey` on `Workspace` instead. The secret always wins when both
are present, and the attribute is never read on the client.

## Run the example place

`PollinationsNpcVillage.rbxlx` is a ready-to-open place with a baseplate, a
gate, and two characters: **Gatekeeper Mara** (can open the gate) and
**Borin** the tavern keeper (talks, does nothing).

1. **File > Open from File...** > `PollinationsNpcVillage.rbxlx`
2. Set the API key as described above.
3. Press **Play**, walk to Mara and press **E**, or type in chat.
   Try `Please, may I open the gate?` and watch it move.

Chat is routed to whichever character is nearest, or to the one you name
(`Mara, ...`).

## Use in your own place

```lua
local PollinationsNpc = require(game.ServerScriptService.PollinationsNpc)

local npc = PollinationsNpc.start({
    name = "Borin",
    persona = "You are Borin, the tavern keeper. Grumpy but kind.",
    model = "nova-fast", -- any id from https://gen.pollinations.ai/text/models
    cooldownSeconds = 3, -- per player, stops one person draining the API
    maxHistoryTurns = 8, -- remembered turns kept per player
    actions = {}, -- optional, see above
    onReply = function(player, reply, actionPerformed)
        print(player.Name, reply.dialogue, actionPerformed)
    end,
})

npc.ask(player, "Hello!")
```

`ask` returns `{ dialogue, action, actionPerformed }`, or `nil` when the call
was skipped (cooldown, no key) or the API failed. Failures never break the
experience; the player just gets nothing that turn.

The API key stays server-side. Nothing on the client ever sees it.

## Building from source

The place file is generated from the Rojo project, so the Luau sources stay the
source of truth:

```bash
rojo build default.project.json -o PollinationsNpcVillage.rbxlx
```

## Testing

```bash
luau tests/logic.luau
```

`tests/logic.luau` runs under the plain Luau CLI, with no Roblox required. It
covers the system prompt, history ordering, and the reply parser: stripping
code fences, extracting JSON out of surrounding prose, and falling back to
plain speech when the model does not return JSON.

## How it talks to Pollinations

`POST https://gen.pollinations.ai/v1/chat/completions` with the standard
`model` / `messages` shape, retried with backoff on 429 and 5xx. Docs:
[gen.pollinations.ai/docs](https://gen.pollinations.ai/docs), model list:
[gen.pollinations.ai/text/models](https://gen.pollinations.ai/text/models).
