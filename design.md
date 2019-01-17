# Design Notes

## Code Flow

1. Initialize values to defaults in a dedicated `setup` Lua module
2. Assuming defaults are OK (URL valid, API key set), proceed
3. Create Vim event hooks to track XP creation per-buffer
4. Create a timer (at a configurable frequency) to attempt to pulse updates, logic:
    1. Get current list of XPs, get timestamp, format into a pulse, store in an
      internal pulse queue
    2. Loop over the pulse queue, validate each (check timestamp is not >1 week
      old, log if it is)
    3. Push the pulse to CS' API, handle error, on success pop from the queue
