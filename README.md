# EmGEMx Token

| Property                  | Value                                       |
| ------------------------- | ------------------------------------------- |
| Name                      | EmGEMx Switzerland                          |
| Symbol                    | EmCH                                        |
| Issuer                    | GemX AG, Zug, CH                            |
| Number of Tokens          | Variable                                    |
| Number of Decimals        | 18                                          |
| Type                      | Crypto Asset (Asset Token)                  |
| Use Case                  | Tokenized Emeralds                          |
| Underlying Asset          | Emeralds                                    |
| Transferable              | Yes                                         |
| Transaction Fee           | No                                          |
| Burn Fee                  | No                                          |
| Initial Price             | Depends on ESU                              |
| Distribution              | Proof-of-Reserve + Buy/DEX/CEX              |
| Technical Base            | ERC-20 on Avalanche                         |
| Public Tradeable          | Yes                                         |
| Governance Function       | No                                          |
| Allowlist                 | No                                          |
| Blocklist                 | Yes                                         |
| Mintable                  | Yes (redeem)                                |
| Burnable                  | Yes (redeem)                                |
| Pausable                  | Yes (all)                                   |
| Roles                     | Owner, Minter, Redeem                       |
| Force Transfer (Clawback) | Yes/No (TBD)                                |
| Max Tokens per Address    | No limit                                    |
| Upgradeable               | Yes                                         |
| Cross-Chain               | Yes (Ethereum, etc.) – CCIP            |
| Other features            | Emerald Standard Unit, Minting based on PoR |

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
