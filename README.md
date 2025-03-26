# EmGEMx Token

## Token Properties

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
| Force Transfer (Clawback) | No                                                |
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
- Admin: owner of the contract, allowed to upgrade the contract, change parameters and assign/revoke roles
- Minter: allowed to mint and burn tokens
- ESU per Token Modifier: allowed to update the ESU per token
- Pauser: allowed to pause/unpause tokens
- Freezer: allowed to freeze/unfreeze tokens
- Limiter: allowed to block/unblock users
- Redeemer: allowed to burn tokens from redeem address

## Functional Requirements

The token may be deployed to multiple blockchain networks, however the core logic of the token (e.g. max supply restriction via PoR oracle, redeem functionality) stays on the `parent chain` which in fact is the **Avalanche C-Chain**.

### ESU

The `ESU` (emerald standard unit) is a value defining how many gemstones are in vault and hence can be minted (based on the `esu_per_token` parameter). Its value is maintained & confirmed/attested by auditors and brought on-chain by an Chainlink PoR oracle data feed.

    - ESU value is written by chainlink
    - Token has an esu_per_token value (set by emgemx)
    - esu_per_token value is updated every month
    - max_tokens = esu / esu_per_token

Example calculation:

1st of March:

- ESU = 2521,13
- esu_per_token = 0,01
- max_tokens = 252.113

1st of April:

- ESU = 2521,13
- esu_per_token = 0.0099
- max_tokens = 254.659,59 => hence ~2.546 new tokens are allowed to be minted compared to previous month

1st of May:

- ESU = 3871,13 (new stones delivered worth 1350 ESU)
- esu_per_token = 0,009801
- max_tokens = 394.972,96

**Monthly amount adjustment**

The following will be done once a month and influences the amount of tokens that are allowed to be minted:

1. Redeem: All redeems are executed and those tokens are burned.

2. ESU adjustment: ESU will be reduced bei 0.1%, allowing us to mint more tokens.

### Redeeming tokens

Users can redeem their tokens for the physical gemstones counterparts, which basically means that the gemstones are taken out of the safe/vault and delivered to the users in exchange for the tokens which eventually get burned. For this the user needs to transfer the tokens to a particular `redeemAddress` specified by emGEMx company and definable inside the token contract. On the parent chain tokens can only be burnt from that special address.

### Burning tokens

In general token burns should be strictly restricted, neither users should be able nor emGEMx on behalf of users should be able to burn tokens from the users (e.g. for a potential clawback scenario in case users lose access to the funds).

However certain functionality requires token burning capabilities. Hence tokens should be burnable solely in the following cases: 
- **on child chains:** only by the CCIP bridge to bring tokens from the child chain (burn) to the parent chain (release). Any tokens previously transfered from parent chain (lock) to child chain (mint) do not require burning for the transfer to settle.
- **on the parent chain:** only as part of the redemption process -> and only by the redeemer from the `redeemAddress`.

### Cross Chain Support

Cross-chain support will be enabled by leveraging Chainlink's CCIP via Token Manager which allows full cross-chain capabilities without changes in the token design/implementation. The only requirement from chainlink is to have a dedicated token owner (implemented via openzeppelin's `Ownable` contract);

Cross-chain token transfers strategies used:

- Source/Parent chain (Avalanche C-Chain): `lock & release`

- All other destination/child chains (e.g. Ethereum Mainnet): `mint & burn`


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
