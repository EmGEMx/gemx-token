# EmGEMx Token

| Property                  | Value                                             |
| ------------------------- | ------------------------------------------------- |
| Name                      | EmGEMx Switzerland                                |
| Symbol                    | EmCH                                              |
| Issuer                    | GemX AG, Zug, CH                                  |
| Number of Tokens          | Variable                                          |
| Number of Decimals        | 8                                                 |
| Type                      | Crypto Asset (Asset Token)                        |
| Use Case                  | Tokenized Emeralds                                |
| Underlying Asset          | Emeralds                                          |
| Transferable              | Yes                                               |
| Transaction Fee           | No                                                |
| Burn Fee                  | No                                                |
| Initial Price             | Depends on ESU                                    |
| Distribution              | Proof-of-Reserve + Buy/DEX/CEX                    |
| Technical Base            | ERC-20 on Avalanche                               |
| Public Tradeable          | Yes                                               |
| Governance Function       | No                                                |
| Allowlist                 | No                                                |
| Blocklist                 | Yes                                               |
| Mintable                  | Yes                                               |
| Burnable                  | Yes (redeem)                                      |
| Pausable                  | Yes (all)                                         |
| Roles                     | Owner, Minter, ESU mod, Pause, Custodian, Limiter |
| Force Transfer (Clawback) | Yes/No (TBD)                                      |
| Max Tokens per Address    | No limit                                          |
| Upgradeable               | Yes                                               |
| Cross-Chain               | Yes (Ethereum, etc.) – CCIP                       |
| Other features            | Emerald Standard Unit, Minting based on PoR       |

Special Features
- Oracle writes Proof-of-Reserve to Blockchain (how many gemstones in ESU are in vault and can be minted)
- Mint function is limited to Proof-of-Reserve (amount of stones) and Emerald Standard Unit (ESU)
- Redeem must be transparent and results in burning of Token
- ESU changes about 0.1% per month (reduction, which results in more tokens to be allowed to be minted)

Roles
- Owner: owner of the contract, allowed to upgrade the contract
- Minter: allowed to mint and burn tokens
- ESU per Token Modifier: allowed to update the ESU per token
- Pauser: allowed to pause/unpause tokens
- Custodian: allowed to freeze/unfreeze tokens
- Limiter: allowed to block/unblock users

## Build, Test, Deploy

### Install

```shell
$ make install
```

### Build

```shell
$ make build
```

### Test

```shell
$ make test
```

### Coverage

```shell
$ make coverage
```

### Deploy

```shell
$ forge script script/DeployToken.s.sol:DeployToken
```
