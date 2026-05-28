# Kimi Code CLI

Kimi Code CLI supports Agent Skills as directories containing `SKILL.md`.

This project-local skill is Kimi-compatible because it lives at:

```text
.codex/skills/ubuntu-server-init/SKILL.md
```

Kimi Code CLI discovers project-level skills from `.kimi/skills/`, `.claude/skills/`, `.codex/skills/`, and `.agents/skills/`. It can also load a custom directory with `--skills-dir`.

Invocation examples:

```text
/skill:ubuntu-server-init initialize root@host for autodl, install mihomo, setup git/cache/netrc
```

or:

```bash
kimi --skills-dir .codex/skills
```

Then in Kimi:

```text
/skill:ubuntu-server-init initialize my Ubuntu server root@host --sandbox autodl --setup-mihomo
```

This skill intentionally uses lowercase hyphen-case naming because Kimi requires skill names to contain only lowercase letters, numbers, and hyphens.
