# GPU Container Notes

Many GPU container providers use a persistent or sandboxed workspace while the root filesystem is smaller or more disposable.

For AutoDL, save data under:

```text
/root/autodl-tmp
```

Use that as the default workspace for this skill.

Prefer storing heavy or persistent data under the workspace:

- cache: `<workspace>/.cache`
- SSH key input: `<workspace>/my_key`
- optional netrc: `<workspace>/.netrc`
- virtualenv: `<workspace>/venv`
- conda: `<workspace>/miniconda3`

Do not assume `/workspace` exists on generic VPS hosts. The deploy script creates the selected workspace path when the selected options need it.

Cache relocation should avoid destructive deletion. Existing non-symlink `~/.cache` is moved to a timestamped backup before the symlink is created.

For restricted networks, initialize Mihomo early enough that subsequent package/model/API downloads can use `127.0.0.1:7890`. The base apt package install still needs direct connectivity unless the machine already has proxy env configured.
