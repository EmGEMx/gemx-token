// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {GEMxToken} from "../src/GEMxToken.sol";

contract GEMxTokenDeployer is Script {
    GEMxToken public token;

    function run(address oracleAddress) public returns (GEMxToken) {
        vm.startBroadcast();

        token = new GEMxToken();
        token.initialize(oracleAddress);

        vm.stopBroadcast();

        return token;
    }
}
