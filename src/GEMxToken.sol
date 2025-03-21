// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20CustodianUpgradeable} from "./ERC20CustodianUpgradeable.sol";
import {ERC20BlocklistUpgradeable} from "./ERC20BlocklistUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract GEMxToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ERC20CustodianUpgradeable,
    ERC20BlocklistUpgradeable,
    ERC20PermitUpgradeable
{
    error NotEnoughReserve();

    AggregatorV3Interface private oracle;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // token minting/burning
    bytes32 public constant ESU_PER_TOKEN_MODIFIER_ROLE = keccak256("ESU_PER_TOKEN_MODIFIER_ROLE"); // allowed to update esu-per-token parameter
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); // pause/unpause token
    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE"); // freeze/unfreeze tokens
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE"); // block/unblock user

    /// @dev Controls whether minting restriction is active (on parent chain) or not (on any other chain).
    uint256 public constant PARENT_CHAIN_ID = 43114; // Avalanche C-Chain

    /*
    ESU Calculation:
    - ESU value is written by chainlink
    - Token has an esu_per_token value (set by emgemx)
    - esu_per_token value is updated every month
    - max_tokens = esu / esu_per_token
    */

    // initial esuPerToken: 0.01
    uint256 private esuPerTokenValue = 1;
    uint256 private esuPerTokenPrecision = 100;

    function initialize(address oracleAddres, string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __Ownable_init(_msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ESU_PER_TOKEN_MODIFIER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(CUSTODIAN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(LIMITER_ROLE, DEFAULT_ADMIN_ROLE);

        oracle = AggregatorV3Interface(oracleAddres);
    }

    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _burn(account, value);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function blockUser(address user) external onlyRole(LIMITER_ROLE) {
        _blockUser(user);
    }

    function unblockUser(address user) external onlyRole(LIMITER_ROLE) {
        _unblockUser(user);
    }

    function getOracleAddress() external view returns (address) {
        return address(oracle);
    }

    function setOracleAddress(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracle = AggregatorV3Interface(newAddress);
    }

    function getEsuPerToken() external view returns (uint256, uint256) {
        return (esuPerTokenValue, esuPerTokenPrecision);
    }

    function setEsuPerToken(uint256 value, uint256 precision) external onlyRole(ESU_PER_TOKEN_MODIFIER_ROLE) {
        esuPerTokenValue = value;
        esuPerTokenPrecision = precision;
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function getMaxSupply() public view returns (uint256) {
        // no max supply restriction on child chains
        if (block.chainid != PARENT_CHAIN_ID) {
            return type(uint256).max;
        }

        return _getEsuFromOracle() * esuPerTokenPrecision / esuPerTokenValue;
    }

    function _isCustodian(address user) internal view override returns (bool) {
        return hasRole(CUSTODIAN_ROLE, user);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20CustodianUpgradeable, ERC20BlocklistUpgradeable)
    {
        // make sure it cannot be minted more than proof of reserve! Only to be checked on parent source chain
        // Code is located here (and not in mint()) so that the logic it is always checked - even if _mint is called from any place)0
        if (block.chainid == PARENT_CHAIN_ID) {
            if (from == address(0) && totalSupply() + amount > getMaxSupply()) {
                revert NotEnoughReserve();
            }
        }

        super._update(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        override(ERC20Upgradeable, ERC20BlocklistUpgradeable)
    {
        super._approve(owner, spender, value, emitEvent);
    }

    function _getEsuFromOracle() private view returns (uint256) {
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = oracle.latestRoundData();

        return uint256(answer);
    }
}
