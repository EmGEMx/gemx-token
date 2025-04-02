// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {EmGEMxToken} from "../../src/EmGEMxToken.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @dev Just for testing contract upgrade functionality.
 */
/// @custom:oz-upgrades-from src/EmGEMxToken.sol:EmGEMxToken
contract EmGEMxTokenV2 is EmGEMxToken {
    uint256 private addedVariable;

    function initializeV2(address oracleAddress, string memory name, string memory symbol) public initializer {
        super.initialize(oracleAddress, name, symbol);
    }

    function name() public pure override returns (string memory) {
        return "emGEMxV2";
    }

    function getAddedVariableValue() public view returns (uint256) {
        return addedVariable;
    }

    function setAddedVariableValue(uint256 _newValue) public {
        addedVariable = _newValue;
    }
}
