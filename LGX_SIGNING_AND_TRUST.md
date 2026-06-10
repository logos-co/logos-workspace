# LGX Package Signing, Trust, and Decentralized Identity

A design overview of how `.lgx` package signing currently works in Logos, how a
trust-prompt UX would fit into the package-manager module, and how the system
could evolve toward decentralized identity verification using DIDs.

---

## 1. How LGX Package Signing Works

### 1.1 Cryptographic Primitives

- **Algorithm:** Ed25519 (via libsodium)
- **Public key:** 32 bytes
- **Secret key:** 64 bytes (libsodium expanded form; the 32-byte seed is what's
  serialized to disk)
- **Signature:** 64 bytes, detached
- **Hashing:** SHA-256 (Merkle tree over package content)

### 1.2 What Gets Signed

The signature is computed over the **raw bytes of `manifest.json`** inside the
`.lgx` archive. The manifest itself contains a Merkle tree of SHA-256 hashes
covering every file in the package, so verifying the signature simultaneously
authenticates content integrity.

```
┌─────────────────────────────────────── package.lgx (tar.gz) ───┐
│                                                                 │
│   manifest.json     ←─── signed bytes                           │
│      ├── name, version, type, category                          │
│      └── hashes:                                                │
│           ├── root            ← Merkle root over everything     │
│           ├── variants        ← hash over all variants/         │
│           ├── variants/linux-x86_64   ← leaf hash               │
│           ├── variants/darwin-arm64   ← leaf hash               │
│           ├── docs            ← leaf hash of docs/              │
│           └── licenses        ← leaf hash of licenses/          │
│                                                                 │
│   manifest.sig      ←─── { did, signature, signer{name,url} }   │
│                                                                 │
│   variants/                                                     │
│     ├── linux-x86_64/                                           │
│     │     └── my_module_plugin.so                               │
│     └── darwin-arm64/                                           │
│           └── my_module_plugin.dylib                            │
│   docs/                                                         │
│   licenses/                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Signing Flow

```
                    ┌──────────────────────┐
                    │  ~/.config/logos/    │
                    │  keys/my-key.jwk     │
                    │  (Ed25519 secret)    │
                    └──────────┬───────────┘
                               │
                               ▼
  package.lgx     ┌─────────────────────────────┐
  ┌────────────┐  │  lgx sign --key my-key      │
  │ manifest   │─▶│                             │
  │ variants/  │  │  1. Validate structure      │
  │ docs/      │  │  2. Recompute Merkle hashes │
  │ licenses/  │  │  3. Verify hashes match     │
  └────────────┘  │     manifest.json values    │
                  │  4. Sign manifest.json bytes│
                  │     with Ed25519            │
                  │  5. Build manifest.sig JSON │
                  │  6. Inject into archive     │
                  └─────────────┬───────────────┘
                                │
                                ▼
                  package.lgx (now signed)
                  ┌──────────────────────────┐
                  │ manifest.json            │
                  │ manifest.sig  ← NEW      │
                  │ variants/ ...            │
                  └──────────────────────────┘
```

### 1.4 Verification Flow

```
   package.lgx (signed)
   ┌──────────────────┐         ┌────────────────────────────────┐
   │ manifest.json    │────────▶│  1. Recompute Merkle tree      │
   │ manifest.sig     │         │     over actual files          │
   │ variants/...     │         │  2. Compare against hashes     │
   └──────────────────┘         │     declared in manifest.json  │
            │                   │     ─→ package_valid           │
            │                   │                                │
            │                   │  3. Read manifest.sig          │
            │                   │  4. Extract public key from    │
            │                   │     did:jwk via didToPublicKey │
            │                   │  5. Decode base64 signature    │
            │                   │  6. Ed25519 verify(            │
            │                   │       manifest.json bytes,     │
            │                   │       publicKey,               │
            │                   │       signature)               │
            │                   │     ─→ signature_valid         │
            │                   │                                │
            │                   │  7. Lookup signer DID in       │
            │                   │     local keyring              │
            │                   │     ─→ trusted_as              │
            │                   └────────────┬───────────────────┘
            │                                │
            ▼                                ▼
                                  lgx_signature_info_t {
                                    is_signed,
                                    signature_valid,
                                    package_valid,
                                    signer_did,
                                    signer_name,    (self-asserted)
                                    signer_url,     (self-asserted)
                                    trusted_as,     (local keyring name)
                                    error
                                  }
```

### 1.5 The `manifest.sig` Document

```json
{
  "version": 1,
  "algorithm": "ed25519",
  "did": "did:jwk:eyJjcnYiOiJFZDI1NTE5Iiwia3R5IjoiT0tQIiwieCI6Ii4uLiJ9",
  "signature": "<base64 — 64 bytes Ed25519 detached signature>",
  "signer": {
    "name": "Logos Foundation",
    "url":  "https://logos.co"
  },
  "linkedDids": []
}
```

### 1.6 The DID: Decoded

`did:jwk` is **self-certifying** — the DID is a deterministic encoding of the
public key itself, so anyone can derive one from the other.

```
  did:jwk:eyJjcnYi...
          │
          ▼ base64url-decode
  {"crv":"Ed25519","kty":"OKP","x":"<base64url 32-byte pubkey>"}
                                      │
                                      ▼ base64url-decode
                                32-byte Ed25519 public key
```

This means: **possession of the matching private key is the only thing the DID
proves**. Nothing more, nothing less.

---

## 2. Identity Data Available at Verification Time

Right now, when verifying a signed `.lgx` package, the user (or the package
manager UI on their behalf) sees four pieces of information about the signer:

```
   ┌──────────────────────┬──────────────────────────────┬──────────────────┐
   │ Field                │ Source                       │ Trust level      │
   ├──────────────────────┼──────────────────────────────┼──────────────────┤
   │ did                  │ Encoded public key           │ CRYPTOGRAPHIC    │
   │ (did:jwk:...)        │ (deterministic)              │ — proves the     │
   │                      │                              │   signer holds   │
   │                      │                              │   the private    │
   │                      │                              │   key            │
   ├──────────────────────┼──────────────────────────────┼──────────────────┤
   │ signer.name          │ Self-asserted at sign time   │ NONE — anyone    │
   │                      │                              │ can claim any    │
   │                      │                              │ name             │
   ├──────────────────────┼──────────────────────────────┼──────────────────┤
   │ signer.url           │ Self-asserted at sign time   │ NONE — same as   │
   │                      │                              │ name             │
   ├──────────────────────┼──────────────────────────────┼──────────────────┤
   │ trusted_as           │ Local keyring entry          │ LOCAL — the user │
   │                      │ (~/.config/logos/            │ previously chose │
   │                      │  trusted-keys/<name>.json)   │ to trust this    │
   │                      │                              │ DID under this   │
   │                      │                              │ name             │
   └──────────────────────┴──────────────────────────────┴──────────────────┘
```

**The DID is the only field that proves anything about identity.** The
`signer.name` and `signer.url` are convenience metadata only — they're displayed
to humans but carry no cryptographic binding to any external identity.

---

## 3. Trust Mechanism for Installation

### 3.1 Current State

`PackageManagerImpl::installPlugin()` already calls
`m_lib->verifyPackageSignature(pluginPath)` and bundles the result into the
response (`signatureStatus`, `signerDid`, `signerName`, `signerUrl`,
`trustedAs`). But install **does not gate on trust** — it reports, and the UI
decides what to do.

### 3.2 Proposed Interactive Flow

```
                          ┌─────────────────────────┐
                          │  User triggers install  │
                          │  (file or download)     │
                          └────────────┬────────────┘
                                       │
                                       ▼
                          ┌─────────────────────────┐
                          │  verifyPackageSignature │
                          └────────────┬────────────┘
                                       │
            ┌──────────────────────────┼──────────────────────────┐
            │                          │                          │
            ▼                          ▼                          ▼
    ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
    │ is_signed    │          │ is_signed    │          │ is_signed    │
    │   = false    │          │   = true     │          │   = true     │
    │              │          │ valid = false│          │ valid = true │
    └──────┬───────┘          └──────┬───────┘          └──────┬───────┘
           │                         │                         │
           ▼                         ▼                         ▼
   ┌───────────────┐         ┌───────────────┐        ┌────────────────┐
   │ "Unsigned"    │         │ "TAMPERED"    │        │  trusted_as    │
   │ dialog        │         │ dialog        │        │  populated?    │
   │               │         │               │        └────────┬───────┘
   │ [Install Any-]│         │ [Cancel]      │                 │
   │ [way] [Cancel]│         │ (no proceed)  │       ┌─────────┴────────┐
   └───────────────┘         └───────────────┘       │                  │
                                                     ▼                  ▼
                                              ┌───────────┐    ┌─────────────┐
                                              │  YES      │    │  NO         │
                                              │ (trusted) │    │ (untrusted) │
                                              └─────┬─────┘    └──────┬──────┘
                                                    │                 │
                                                    ▼                 ▼
                                            silent install      TRUST PROMPT
                                            (just emit
                                             "trusted as X"
                                             in response)
```

### 3.3 The Trust Prompt

When a package is signed with a valid signature, but the DID is **not** in the
local keyring, surface this dialog:

```
┌──────────────────────────────────────────────────────────────┐
│   Install "logos-chat-module" v1.4.2                         │
│                                                              │
│   This package is signed.                                    │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  Public key (DID):                                   │  │
│   │    did:jwk:eyJjcnYiOiJFZDI1NTE5Iiwia3R5...          │  │
│   │                                                      │  │
│   │  Claims to be:                                       │  │
│   │    Logos Foundation                                  │  │
│   │    https://logos.co                                  │  │
│   │                                                      │  │
│   │  ⚠ This signer is NOT in your trusted keyring.       │  │
│   │  The name and URL above are self-asserted and        │  │
│   │  cannot be verified.                                 │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
│   [ Trust Once ]   [ Always Trust ]   [ Cancel ]             │
└──────────────────────────────────────────────────────────────┘
```

### 3.4 Per-Choice Behavior

```
   ┌────────────────┬─────────────────────────────────────────────┐
   │ Trust Once     │ Proceed with install. Do not modify keyring.│
   │                │ Next install from same DID prompts again.   │
   ├────────────────┼─────────────────────────────────────────────┤
   │ Always Trust   │ Proceed with install. Add DID to            │
   │                │ ~/.config/logos/trusted-keys/<name>.json    │
   │                │ using the self-asserted signer.name as      │
   │                │ default keyring name. Future installs from  │
   │                │ this DID proceed silently.                  │
   ├────────────────┼─────────────────────────────────────────────┤
   │ Cancel         │ Abort installation. No state change.        │
   └────────────────┴─────────────────────────────────────────────┘
```

### 3.5 Wiring it Through the Module

The package-manager module already has an `emitEvent` callback for async
notifications. The trust prompt would extend this with a request/response pair:

```
  PMU (UI)                Package Manager Module        lgx C API
     │                              │                        │
     │  installPlugin(path)         │                        │
     ├─────────────────────────────▶│                        │
     │                              │  verifyPackageSignature│
     │                              ├───────────────────────▶│
     │                              │◀───── sigInfo ─────────┤
     │                              │                        │
     │                              │  if signed && !trusted │
     │                              │  && !invalid:          │
     │                              │                        │
     │  emitEvent(                  │                        │
     │    "signatureTrustPrompt",   │                        │
     │    {pkg, did, name, url})    │                        │
     │◀─────────────────────────────┤                        │
     │                              │                        │
     │  [User chooses "Always"]     │                        │
     │                              │                        │
     │  respondToTrustPrompt(       │                        │
     │    pkg, "always")            │                        │
     ├─────────────────────────────▶│                        │
     │                              │  lgx_keyring_add(...)  │
     │                              ├───────────────────────▶│
     │                              │  installPluginFile(...)│
     │                              ├───────────────────────▶│
     │                              │◀──── installed ────────┤
     │◀──── install response ───────┤                        │
```

The C API already exposes `lgx_keyring_add()` for the "Always Trust" path —
the module just needs to plumb the user's decision back through.

### 3.6 Optional: Signature Policy

A workspace- or system-level policy could pre-decide some of these prompts:

```
   ┌──────────┬────────────────────────────────────────────────────┐
   │ NONE     │ Skip signature checks entirely. (CI / dev mode)    │
   ├──────────┼────────────────────────────────────────────────────┤
   │ WARN     │ Default. Prompt user when signed-but-untrusted     │
   │          │ or unsigned. Block on invalid signatures.          │
   ├──────────┼────────────────────────────────────────────────────┤
   │ REQUIRE  │ Reject unsigned packages outright. Reject          │
   │          │ untrusted signers outright. Only proceed when      │
   │          │ trusted_as is populated.                           │
   └──────────┴────────────────────────────────────────────────────┘
```

---

## 4. Future: Decentralized Identity via DIDs

### 4.1 The Problem with Today's Model

`did:jwk` is self-certifying — it proves "the holder of this private key signed
this package," nothing more. The system can verify that two packages were
signed by the same key, but it has no way to verify that
`signer.name: "Logos Foundation"` is legitimate without already knowing the
public key out-of-band.

This is **trust-on-first-use** (TOFU), the same model as SSH host keys. It
works, but every new signer requires manual approval, and there's no path to
"verified identity."

The `linkedDids` field in `manifest.sig` is reserved for exactly this evolution.

### 4.2 The DID Method Landscape

```
   ┌──────────────────┬───────────────────┬────────────────────────────────┐
   │ DID Method       │ Anchor            │ What it proves                 │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:jwk          │ The key itself    │ Possession of private key      │
   │ (current)        │                   │                                │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:web          │ DNS + HTTPS       │ Control of a domain            │
   │                  │                   │ (logos.co publishes the key)   │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:pkh          │ Blockchain        │ Control of a chain account     │
   │                  │ (eip155, sol, …)  │ (signed attestation on-chain)  │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:ens          │ ENS contract      │ Ownership of an ENS name       │
   │                  │ (Ethereum)        │ (logos.eth → key in TXT rec.)  │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:ethr         │ EVM registry      │ Smart-contract registered key  │
   ├──────────────────┼───────────────────┼────────────────────────────────┤
   │ did:peer         │ Peer-to-peer      │ Out-of-band exchange between   │
   │                  │ exchange          │ two parties                    │
   └──────────────────┴───────────────────┴────────────────────────────────┘
```

### 4.3 did:web — Domain-Anchored Identity

The simplest evolution. Looks like TLS certificates, but with no central CA.

```
   manifest.sig                    https://logos.co/.well-known/did.json
   ┌─────────────────────┐         ┌──────────────────────────────────┐
   │ did: did:jwk:...    │         │ {                                │
   │ linkedDids: [       │         │   "id": "did:web:logos.co",      │
   │   "did:web:logos.co"│ ◀──────▶│   "verificationMethod": [{       │
   │ ]                   │  match  │     "id": "did:web:logos.co#k1", │
   │ signature: "..."    │         │     "type": "Ed25519...",        │
   └─────────────────────┘         │     "publicKeyJwk": {            │
                                   │       "crv": "Ed25519",          │
                                   │       "x": "<same key as jwk>"   │
                                   │     }                            │
                                   │   }]                             │
                                   │ }                                │
                                   └──────────────────────────────────┘
```

**Verification:**
1. Fetch `https://logos.co/.well-known/did.json` (HTTPS provides transport
   trust)
2. Confirm the public key in the DID Document matches the `did:jwk` in
   `manifest.sig`
3. Display: **"Verified: this key is published by logos.co"**

This gives domain-level identity without a central registry. If Logos Foundation
controls `logos.co`, they control their identity.

### 4.4 did:pkh — Blockchain-Anchored Identity

The `linkedDids` array can carry chain-rooted DIDs:

```json
"linkedDids": [
  "did:pkh:eip155:1:0xAbC123dEf456..."
]
```

```
   ┌─────────────────────┐
   │ Ed25519 signing key │
   │ (did:jwk in pkg)    │
   └──────────┬──────────┘
              │  linked via signed attestation
              ▼
   ┌─────────────────────┐         ┌──────────────────────────┐
   │ EIP-712 attestation │────────▶│  Ethereum mainnet        │
   │ "I (0xAbC...) attest│         │  (or any chain, IPFS,    │
   │  to controlling     │         │  L2, attestation         │
   │  did:jwk:eyJj...    │         │  registry — verifiable   │
   │  on 2026-04-01"     │         │  on-chain or off-chain)  │
   │ signed by 0xAbC...  │         │                          │
   └─────────────────────┘         └──────────────────────────┘
```

**Verification:**
1. Fetch the attestation (on-chain log, IPFS, or attached to manifest.sig)
2. Verify the chain-account signature on the attestation
3. Confirm the attestation references the same `did:jwk`
4. Display: **"Linked to Ethereum address 0xAbC...123"** (and resolve via ENS
   for human-readable name if available)

No server, no CA, no registry — purely cryptographic and decentralized.

### 4.5 The Trust Ladder

With multiple DID methods stacked, the install dialog can show graduated trust:

```
   ┌───────┬─────────────────────────────────┬─────────────────┬───────────┐
   │ Level │ Meaning                         │ Indicator       │ UX        │
   ├───────┼─────────────────────────────────┼─────────────────┼───────────┤
   │   0   │ Unsigned                        │ ⚠ red           │ confirm   │
   │   1   │ Signed, valid, unknown DID      │ ⚠ yellow        │ prompt    │
   │   2   │ Signed, DID in local keyring    │ ✓ green         │ silent    │
   │       │ (TOFU)                          │ "trusted as X"  │           │
   │   3   │ Signed + did:web verified       │ ✓✓ green        │ silent    │
   │       │ (key matches a domain)          │ "verified:      │           │
   │       │                                 │  logos.co"      │           │
   │   4   │ Signed + did:pkh verified       │ ✓✓✓ green       │ silent    │
   │       │ (linked to on-chain identity    │ "verified       │           │
   │       │  with valid attestation)        │  on-chain"      │           │
   └───────┴─────────────────────────────────┴─────────────────┴───────────┘
```

Higher levels **stack** — they don't replace lower ones. A locally-trusted DID
that *also* resolves via did:web is still locally trusted; the did:web result
is additional assurance, optionally cached.

### 4.6 The Enhanced Trust Prompt

```
┌───────────────────────────────────────────────────────────────────┐
│   Install "logos-chat-module" v1.4.2                              │
│                                                                   │
│   ┌─────────────────────────────────────────────────────────┐    │
│   │  Signing key (DID):                                     │    │
│   │     did:jwk:eyJjcnYiOiJFZDI1NTE5...                    │    │
│   │                                                         │    │
│   │  Self-asserted identity:                                │    │
│   │     "Logos Foundation"  https://logos.co                │    │
│   │                                                         │    │
│   │  Verified identities:                                   │    │
│   │     ✓ did:web:logos.co                                  │    │
│   │       (key published at logos.co/.well-known/did.json)  │    │
│   │                                                         │    │
│   │     ✓ did:pkh:eip155:1:0xAbC123dEf456                   │    │
│   │       (on-chain attestation, signed 2026-04-01)         │    │
│   │       resolves via ENS to: logos.eth                    │    │
│   │                                                         │    │
│   │  Trust level: ✓✓✓ Verified on-chain                     │    │
│   └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│   [ Trust Once ]   [ Always Trust ]   [ Cancel ]                  │
└───────────────────────────────────────────────────────────────────┘
```

### 4.7 Why This Aligns with Logos

The Logos ecosystem values decentralization and self-sovereignty. Traditional
package signing uses GPG keyservers, central registries, or CA-issued
certificates — all single points of failure and trust.

DID-based verification means:

```
   ┌────────────────────────┬─────────────────────────────────────────┐
   │ Property               │ How DIDs deliver it                     │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ No central authority   │ DIDs are self-resolved (did:jwk),       │
   │                        │ DNS-resolved (did:web), or chain-       │
   │                        │ resolved (did:pkh, did:ens). No         │
   │                        │ gatekeeper decides who can sign.        │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ User-chosen trust      │ Users pick their model: TOFU,           │
   │   model                │ domain-verified, on-chain. Each layer   │
   │                        │ is optional and stackable.              │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ Self-sovereign         │ Signers prove identity via keys/        │
   │   identity             │ accounts they already control. No       │
   │                        │ application required.                   │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ Decentralized          │ Revocation lives in the DID Document    │
   │   revocation           │ itself (rotate keys in did.json,        │
   │                        │ update on-chain registry). No CRL       │
   │                        │ servers, no OCSP responders.            │
   ├────────────────────────┼─────────────────────────────────────────┤
   │ Censorship resistance  │ A blockchain-anchored DID can't be      │
   │                        │ revoked by a registry, can't be         │
   │                        │ deplatformed, can't be seized.          │
   └────────────────────────┴─────────────────────────────────────────┘
```

---

## 5. Summary

**Today** the `.lgx` signing system implements:

- Ed25519 detached signatures over `manifest.json`
- Merkle-tree content hashing (signature transitively covers all files)
- `did:jwk` as a self-certifying signer identifier
- A local keyring for trust-on-first-use (TOFU)
- All CLI tooling (`lgx keygen`, `lgx sign`, `lgx verify`, `lgx keyring …`)
- Verification result wired through `installPlugin()` in the package-manager
  module

**The next step** is to gate installation on user trust decisions, surfacing
the signer's DID alongside their self-asserted name/URL and offering
*Trust Once / Always Trust / Cancel*.

**The future** is to layer richer DID methods (`did:web`, `did:pkh`,
`did:ens`) on top of the existing `did:jwk` foundation via the already-reserved
`linkedDids` field — giving users graduated, decentralized assurance about
who's actually behind a package, without ever introducing a central trust
authority.
