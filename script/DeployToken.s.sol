// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GEMxToken} from "../src/GEMxToken.sol";

contract DeployToken is Script {
    GEMxToken public token;

    function run() public returns (GEMxToken) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        vm.startBroadcast();

        token = new GEMxToken();
        //NetworkConfig memory config = helperConfig.activeNetworkConfig();
        (address proofOfReserveOracle) = helperConfig.activeNetworkConfig();
        //address oracleAddress = config.proofOfReserveOracle;
        token.initialize(proofOfReserveOracle);

        vm.stopBroadcast();

        return token;
    }
}
