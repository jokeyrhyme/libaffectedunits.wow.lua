# libaffectedunits.wow.lua

re-learning WoW Lua; building a helper to count units affected by player actions


## Status

Not ready for use, just working out the theory and hoping to get feedback.


## What does this do?

When finished, the idea is to provide other addons with a table of aggregates.
Each aggregate records the number of harmed or helped units over the last `n` seconds.

For example:

```lua
{
  1: {
    "harm": 2,
    "help": 0
  },
  2: {
    "harm": 5,
    "help": 2
  },
  -- ... ,
  10: {
    "harm": 8,
    "help": 3
  },
}
```

Armed with these aggregates, addons should be able to infer, primarily,
the number of friendly or hostile units the player is currently engaged with.


## Community

Hopefully, there'll be discussions about this work in the following places:

- https://github.com/jokeyrhyme/libaffectedunits.wow.lua/issues

- http://forums.wowace.com/showthread.php?p=345011

- http://www.wowace.com/addons/weakauras-2/forum/127461-lib-affected-units-count-currently-engaged-friends/


## Resources

- http://wowwiki.wikia.com/wiki/AddOn_programming_tutorial/Introduction

- http://wowwiki.wikia.com/wiki/API_COMBAT_LOG_EVENT

- http://www.wowace.com/addons/ace3/pages/api/ace-timer-3-0/
