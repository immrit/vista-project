# Telegram Emoji Assets

This project uses emoji assets sourced from the official Telegram Android repository:

- Repository: `https://github.com/DrKLO/Telegram`
- Path: `TMessagesProj/src/main/assets/emoji`
- Mapping source: `TMessagesProj/src/main/java/org/telegram/messenger/EmojiData.java`

## License

Telegram Android source code and bundled assets are provided under GNU GPL v2 or later.
See Telegram repository license details for full terms:

- `https://github.com/DrKLO/Telegram/blob/master/LICENSE`

If you redistribute this app with these assets, ensure license obligations are met.

## Reproducible Sync

Run:

```bash
python tool/emoji/sync_telegram_emoji.py --ref <commit-or-branch>
```

The script updates:

- `assets/emoji/telegram/**`
- `lib/features/emoji/data/telegram_emoji_map.json`
- `tool/emoji/telegram_emoji_manifest.json`

