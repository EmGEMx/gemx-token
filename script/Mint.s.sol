// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {EmGEMxToken} from "../src/EmGEMxToken.sol";

contract Mint is Script {
    function run(address tokenAddress, address account, uint256 amount) public {
        vm.startBroadcast();

        EmGEMxToken token = EmGEMxToken(tokenAddress);
        bytes32 role = token.MINTER_ROLE();
        console.log("Sender:", msg.sender);
        require(token.hasRole(role, msg.sender), "Sender is not minter");

        token.mint(account, amount);

        vm.stopBroadcast();
    }
}
