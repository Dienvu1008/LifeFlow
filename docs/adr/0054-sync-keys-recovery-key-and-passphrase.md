# ADR-0054: Keys of end-to-end sync: recovery key and passphrase

- Status: Accepted (P04 task T1b, 2026-11-14; the passphrase minimum and the confirmation by the owner, 2026-11-14)
- Date: 2026-11-14
- Deciders: Project owner (D12, D15, the passphrase minimum), implementation
- Related: [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md) §5, [ADR-0021](0021-encryption-at-rest-platform-posture.md) / [ADR-0022](0022-windows-encryption-at-rest.md) (secure storage of keys), spike S-15 in [spike-results.md](../spikes/spike-results.md)

## Decision
1. **Where keys live.** The workspace key (256 random bits) is kept only in platform secure storage, in the slot `lifeflow.sync.key.<workspaceId>`, through the same key-slot port as the database keys. It is never in the database, a plain file or a log. The server receives it only wrapped.
2. **Wrapping.** `WrappedKey` = a format byte (1), then AES-256-GCM of the workspace key under the unlock key, with the workspace id as associated data. A wrapping of an unknown format is refused rather than misread. The unlock key is HKDF-SHA-256 of the recovery key, or Argon2id of the passphrase (19 MiB, 2 passes, 1 lane; a 16-byte random salt kept with the wrapping).
3. **Recovery key (the default).** 256 random bits shown as 24 words of the BIP-39 English list (VS-43) with an 8-bit checksum, so a mistyped or swapped word is almost always caught, with a message that says which word or why. The QR text is `LIFEFLOW RECOVERY 1` and the words in capitals, so the code can use QR's alphanumeric mode. Typed words, pasted words and the QR text all parse; case and spaces do not matter. **Before the key is kept, the user types back two words** at random positions (owner, 2026-11-14).
4. **Passphrase.** At least 12 characters, spaces at either end not counted, in any script, after Unicode NFC. It must not be a common password (zxcvbn's list, VS-44), also not with digits, punctuation or symbols added at either end, and not a short piece or a common word repeated (owner, 2026-11-14). Spaces at either end are ignored when unlocking too.
5. **Set up, then keep.** A setup (a new key and its wrapping) is kept on the device only after the confirmation; unlocking on a second device keeps the key only when the unwrapping succeeds.
6. **Switching or changing the unlock** re-wraps the same workspace key; no record is sealed again. **Reset** makes a new workspace key; records sealed under the old one cannot be opened with it, and the server ids change, so T4 deletes the old server copy and uploads afresh.

## Consequences
- `cryptography` 2.9.0 is now shipped (FF-ARCH-07 inventory: 131 packages and libraries). The BIP-39 and zxcvbn notices are on the app's licenses page.
- The screens for showing, scanning and typing the key are T5; T4 uploads the wrapping to `account_workspaces`.
- **Unicode normalisation (owner, 2026-11-14):** passphrases are put in NFC (`unorm_dart`, VS-45) after the spaces at either end are removed, both when checked and when stretched, so a Vietnamese passphrase unlocks whether a keyboard wrote precomposed letters or combining marks; the length rule counts the normalised text.
- Tests: `sync_keys_test.dart`, 16 tests (sealing, ids, the word list's hash, words and QR text, the two-word check, the passphrase rules, NFC, the keyring's set up, keep, unlock, re-wrap, reset and format check, end to end, speed). Mutations 15/15 killed. Measured on the development PC: 10 000 records sealed in 0.55 s and opened in 0.42 s; one Argon2id derivation 107 ms.
