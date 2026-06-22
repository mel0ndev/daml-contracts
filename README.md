# Canton Tokenized Equity Prototype

A tokenized stock prototype on the [Canton Network](https://www.canton.network/) using [Daml](https://www.digitalasset.com/developers) smart contracts and a Zig client that drives the full workflow over Canton's HTTP JSON Ledger API v2.

Demonstrates all four required scenarios:
- Create an equity instrument for a ticker (e.g. `AAPL`)
- Allowlist a party to receive the instrument via a propose-accept account handshake
- Mint shares to that party (Credit)
- Query the balance held by the party

---

## Project Structure

```
.
├── daml/HelloWorld/          # Daml smart contracts + Canton sandbox config
│   ├── daml.yaml             # project manifest (sdk 3.5.1, name NasdaqDemo)
│   └── daml/
│       ├── Instrument.daml   # equity instrument definition (ticker + issuer)
│       ├── AccountProposal.daml  # allowlist gate — custodian proposes, owner accepts
│       ├── Account.daml      # accepted account; holds Credit and PayDividend choices
│       ├── Holding.daml      # ownership record (owner, symbol, amount)
│       ├── Main.daml         # runnable Daml Script demo (all four flows)
│       └── Test.daml         # 6 unit tests covering flows + access control
│
└── client/                   # Zig client — drives the same four flows over HTTP
    ├── build.zig
    ├── build.zig.zon
    └── src/
        ├── ledger.zig        # HTTP wrapper: allocateParty, create, exercise, balanceOf
        └── main.zig          # demo entry point
```

---

## Prerequisites

- [Daml SDK 3.5.1](https://docs.daml.com/getting-started/installation.html) — provides `daml`, `daml sandbox`, `daml script`, `daml test`
- [Zig 0.16.0+](https://ziglang.org/download/) — to build and run the Zig client
- Canton sandbox running locally (started via `daml sandbox`, see below)

---

## Running the Daml Script Demo

This runs all four flows inside the Daml Script environment — no HTTP server needed.

```bash
cd daml/HelloWorld

# 1. Build the DAR
daml build

# 2. Run the demo script (allocates parties, creates instrument, allowlists Alice, mints, prints balance)
daml script \
  --dar .daml/dist/NasdaqDemo-0.0.1.dar \
  --script-name Main:demo \
  --ledger-host localhost \
  --ledger-port 6865
```

The script will print each step and Alice's final AAPL balance to stdout.

---

## Running the Tests

```bash
cd daml/HelloWorld
daml test
```

Six tests run:
- `testAcceptCreatesAccount` — proposal → Account has correct parties
- `testOnlyOwnerCanAccept` — custodian cannot accept their own proposal
- `testCreditMintsHolding` — Credit produces a Holding with correct fields
- `testOnlyCustodianCanCredit` — owner cannot mint to themselves
- `testBalanceSumsHoldings` — balance aggregates across multiple Holdings, ignores other symbols
- `testPayDividendPaysProRata` — dividend payout is ratePerShare × equity amount

---

## Running the Zig Client

The Zig client connects to the Canton sandbox HTTP JSON Ledger API (port 6864) and runs the same four flows programmatically.

### 1. Start the Canton sandbox

```bash
cd daml/HelloWorld
daml sandbox
```

Leave this running. The HTTP Ledger API v2 is available at `http://localhost:6864`.

### 2. Build and upload the DAR

```bash
# in daml/HelloWorld
daml build
daml ledger upload-dar \
  --host localhost --port 6865 \
  .daml/dist/NasdaqDemo-0.0.1.dar
```

### 3. Run the client

```bash
cd client
zig build run
```

The client will:
1. Allocate two parties (`Bank`, `Alice`)
2. Create the `MU` instrument under Bank
3. Create an `AccountProposal` (Bank → Alice) and have Alice `Accept` it
4. Credit Alice with 100 shares of `MU`
5. Print Alice's `MU` balance

---

## Design Notes

The three-contract model (`Instrument` / `Account` / `Holding`) mirrors the decomposition used by [Daml Finance](https://docs.daml.com/daml-finance/concepts/asset-model.html): separating *what* is held from *how much* from *who may hold it*. This means corporate actions (which change the instrument definition) don't require touching every holding individually.

The `AccountProposal → Accept` handshake is the allowlist gate. A party cannot receive holdings without an accepted `Account` — the custodian cannot unilaterally grant one, and the owner cannot create one without the custodian's proposal. This mirrors the compliance-by-design requirement for permissioned securities.
