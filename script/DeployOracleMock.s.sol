// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

/**
 * @title Deployment script for the chainlink data feed oracle mock.
 */
contract DeployOracleMock is Script {
    function run() public returns (MockV3Aggregator) {
        HelperConfig helperConfig = new HelperConfig();
        uint256 mockValue = helperConfig.PROOF_OF_RESERVE_MOCK();

        vm.startBroadcast();

        MockV3Aggregator mock = deploy(mockValue);

        vm.stopBroadcast();

        return mock;
    }

    function deploy(uint256 mockValue) public returns (MockV3Aggregator) {
        MockV3Aggregator mock = new MockV3Aggregator(int256(mockValue));
        console.log("Oracle mock deployed at: ", address(mock));
        return mock;
    }
}
