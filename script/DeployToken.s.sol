// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {EmGEMxToken} from "../src/EmGEMxToken.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract DeployToken is Script {
    EmGEMxToken public token;

    function run() public returns (EmGEMxToken) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();

        (address esuOracle) = helperConfig.activeNetworkConfig();
        if (esuOracle == address(0x0)) {
            uint256 mockValue = helperConfig.PROOF_OF_RESERVE_MOCK();
            MockV3Aggregator mock = createProofOrReserveMock(mockValue);
            esuOracle = address(mock);
        }
        console.log("Oracle address:", esuOracle);

        token = new EmGEMxToken();
        console.log("Token address:", address(token));

        string memory tokenName = vm.envString("TOKEN_NAME"); // "EmGEMx Switzerland"
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL"); // "EmCH"

        token.initialize(esuOracle, tokenName, tokenSymbol);

        vm.stopBroadcast();

        return token;
    }

    function createProofOrReserveMock(uint256 reserve) private returns (MockV3Aggregator) {
        MockV3Aggregator mock = new MockV3Aggregator(int256(reserve));
        console.log("Oracle mock deployed at:", address(mock));
        return mock;
    }
}
