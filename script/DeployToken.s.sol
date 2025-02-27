// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GEMxToken} from "../src/GEMxToken.sol";

contract DeployToken is Script {
    GEMxToken public token;

    function run() public returns (GEMxToken) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();

        token = new GEMxToken();
        (address proofOfReserveOracle) = helperConfig.activeNetworkConfig();

        string memory tokenName = vm.envString("TOKEN_NAME"); // "EmGemX Switzerland"
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL"); // "EmCH"

        token.initialize(proofOfReserveOracle, tokenName, tokenSymbol);

        vm.stopBroadcast();

        return token;
    }
}
