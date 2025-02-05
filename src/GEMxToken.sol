// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20Upgradeable,
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ISolvencyOracle, SolvencyOracleMock} from "./SolvencyOracleMock.sol";

contract GEMxToken is ERC20BurnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    ISolvencyOracle solvencyOracle;

    event ProofOfSolvencyChanged(uint256 amount);

    error NotEnoughReserve();

    function initialize(address proofOfSolvencyOracleAddress) public initializer {
        __ERC20_init("GEMxToken", "GEMX");
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);

        solvencyOracle = SolvencyOracleMock(proofOfSolvencyOracleAddress);
    }

    function getProofOfSolvency() external view returns (uint256) {
        return solvencyOracle.getProofOfSolvency();
    }

    function mint(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyRole(MINTER_ROLE) {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable) {
        // make sure it cannot be minted more than proof of reserve!
        if (from == address(0) && totalSupply() + amount > this.getProofOfSolvency()) {
            revert NotEnoughReserve();
        }

        super._update(from, to, amount);
    }
}
