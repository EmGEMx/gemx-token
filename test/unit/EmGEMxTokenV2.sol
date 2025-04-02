// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {EmGEMxToken} from "../../src/EmGEMxToken.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @custom:oz-upgrades-from src/EmGEMxToken.sol:EmGEMxToken
contract EmGEMxTokenV2 is EmGEMxToken {
    function initializeV2(address oracleAddress, string memory name, string memory symbol) public initializer {
        super.initialize(oracleAddress, name, symbol);
    }

    function name() public pure override returns (string memory) {
        return "emGEMxV2";
    }
}
