// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

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
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ERC20CustodianUpgradeable,
    ERC20BlocklistUpgradeable
{
    error NotEnoughReserve();

    AggregatorV3Interface private oracle;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ESU_ROLE = keccak256("ESU_ROLE"); // allowed to update esu value
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); // pause/unpause token
    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE"); // freeze/unfreeze tokens
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE"); // block/unblock user

    /*
    ESU Calculation:    TODO: this needs to be confirmed!
    - ESU value is written by chainlink
    - Token has an esu_per_token value
    - max_tokens = esu * esu_per_token
    */

    uint256 private esuPerTokenValue = 1;
    uint256 private esuPerTokenPrecision = 1000;

    function initialize(address oracleAddres, string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __Ownable_init(_msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ESU_ROLE, DEFAULT_ADMIN_ROLE);
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

    // TODO: ESU and PoR logic still be confirmed!
    function getEsu() external view returns (uint256, uint256) {
        return (esuPerTokenValue, esuPerTokenPrecision);
    }

    function setEsuValue(uint256 esu, uint256 precision) external onlyRole(ESU_ROLE) {
        esuPerTokenValue = esu;
        esuPerTokenPrecision = precision;
    }

    function _isCustodian(address user) internal view override returns (bool) {
        return hasRole(CUSTODIAN_ROLE, user);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20CustodianUpgradeable, ERC20BlocklistUpgradeable)
    {
        // make sure it cannot be minted more than proof of reserve!
        if (from == address(0) && totalSupply() + amount > _getProofOfReserve()) {
            revert NotEnoughReserve();
        }

        super._update(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        override(ERC20Upgradeable, ERC20BlocklistUpgradeable)
    {
        super._approve(owner, spender, value, emitEvent);
    }

    function _getProofOfReserve() private view returns (uint256) {
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
