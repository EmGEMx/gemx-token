// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GEMxToken} from "../src/GEMxToken.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract DeployToken is Script {
    GEMxToken public token;

    function run() public returns (GEMxToken) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();

        (address proofOfReserveOracle) = helperConfig.activeNetworkConfig();
        if (proofOfReserveOracle == address(0x0)) {
            MockV3Aggregator mock = new MockV3Aggregator(helperConfig.PROOF_OF_RESERVE_MOCK());
            proofOfReserveOracle = address(mock);
        }

        token = new GEMxToken();
        
        string memory tokenName = vm.envString("TOKEN_NAME"); // "EmGemX Switzerland"
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL"); // "EmCH"

        token.initialize(proofOfReserveOracle, tokenName, tokenSymbol);

        vm.stopBroadcast();

        return token;
    }

    function createProofOrReserveMock(uint256 reserve) private returns (MockV3Aggregator) {
        MockV3Aggregator mock = new MockV3Aggregator(int256(reserve));
        console.log("Mock deployed under:", address(mock));
        return mock;
    }
}
