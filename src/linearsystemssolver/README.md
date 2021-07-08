## LinearSystemsSolver

Solves linear systems in this format:

```
[a  b | y]
[c  d | z]

mutSystem = {
	{a, b},
	{c, d},
}

mutOutput = {y, z}

returns solution {x0, x1}
```

## Notes
system and output get destroyed in the process
