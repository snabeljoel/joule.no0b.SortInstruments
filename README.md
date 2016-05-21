# joule.no0b.SortInstruments
Renoise tool for sorting the instrument list using various criterias

TODO for v1.0:

- Optimize the final sorting algorithm (currently uses bubble sorting).

Premises:
- Renoise provides a swap_at(src, dst) function for changing an instruments position.
- The more sample data an instrument has, the more time it takes to change its position.
- Bubble sorting is suboptimal since it might push heavy instruments thru many swaps (no "weight" optimization)

Solution:
- Optimize the swapping sequence by minimizing the amount of weight swapped. This can be done by always pushing forward a weightless instrument.
- Swap the lightest instrument to an empty slot
- Swap the empty instrument with correct instrument
- When the lightest instrument is the correct, swap it in and start a new swap cycle.
- Best case: N+1 swaps. Worst case: 3N/2 swaps. (?)
