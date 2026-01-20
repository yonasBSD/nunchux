# Trusted Configs

Nunchux supports local `.nunchuxrc` files in project directories. When you `cd` into a directory containing a `.nunchuxrc`, nunchux will use that configuration instead of your home config.

## Security

Since config files can execute arbitrary commands (via `cmd`, `status`, etc.), loading untrusted configs is a security risk. For example, a malicious repository could include a `.nunchuxrc` that runs harmful commands when you open nunchux.

To protect against this, nunchux prompts you before loading local configs:

```
┌─────────── Trust Config? ───────────┐
│ Found local config: /path/to/.nunchuxrc
│ Trust this config?
│
│ > No
│   Yes, once
│   Yes, always
│   No, never
└─────────────────────────────────────┘
```

## Trust Behavior

- **No**: Skip the local config, use home config instead. You'll be asked again next time.
- **Yes, once**: Load the local config this time only. You'll be asked again next time.
- **Yes, always**: Load the local config and add to trusted list. You won't be asked again.
- **No, never**: Skip and permanently block this config. Nunchux will always skip it without prompting.

## Trusted Configs File

Trusted paths are stored in:

```
~/.local/state/nunchux/trusted_configs
```

This is a simple text file with one path per line. You can edit it manually to add or remove trusted paths.

### Example

```
/home/user/projects/myapp/.nunchuxrc
/home/user/work/api/.nunchuxrc
```

## Blocked Configs File

Blocked paths (from "No, never") are stored in:

```
~/.local/state/nunchux/blocked_configs
```

Same format as the trusted file - one path per line.

## Config Search Order

Nunchux searches for config files in this order:

1. `NUNCHUX_RC_FILE` environment variable (trusted, explicit)
2. `.nunchuxrc` in current directory or parent directories (requires trust)
3. `~/.config/nunchux/config` (trusted, home directory)

## Revoking Trust or Unblocking

To revoke trust or unblock a config, edit the corresponding file and remove the path:

```bash
# Edit trusted configs
vim ~/.local/state/nunchux/trusted_configs

# Edit blocked configs
vim ~/.local/state/nunchux/blocked_configs

# Or reset everything
rm ~/.local/state/nunchux/trusted_configs
rm ~/.local/state/nunchux/blocked_configs
```
