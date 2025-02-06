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

pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20Upgradeable,
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract GEMxToken is ERC20BurnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    AggregatorV3Interface oracle;

    error NotEnoughReserve();

    function initialize(address oracleAddres) public initializer {
        __ERC20_init("GEMxToken", "GEMX");
        __ERC20Burnable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);

        oracle = AggregatorV3Interface(oracleAddres);
    }

    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _burn(account, value);
    }

    function getOracleAddress() public returns (address) {
        return address(oracle);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable) {
        // make sure it cannot be minted more than proof of reserve!
        if (from == address(0) && totalSupply() + amount > _getProofOfReserve()) {
            revert NotEnoughReserve();
        }

        super._update(from, to, amount);
    }

    function _getProofOfReserve() private view returns (uint256) {
        (, int256 answer,,,) = oracle.latestRoundData();

        return uint256(answer);
    }
}
