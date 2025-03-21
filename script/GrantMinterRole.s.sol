// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {GEMxToken} from "../src/GEMxToken.sol";

contract GrantMinterRole is Script {
    function run(address tokenAddress, address newMinter) public {
        vm.startBroadcast();

        GEMxToken token = GEMxToken(tokenAddress);
        bytes32 role = token.MINTER_ROLE();
        if (token.hasRole(role, newMinter)) {
            console.log("Address is already minter");
        } else {
            token.grantRole(token.MINTER_ROLE(), newMinter);
        }

        vm.stopBroadcast();
    }
}
