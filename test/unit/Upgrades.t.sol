// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {EmGEMxToken} from "../../src/EmGEMxToken.sol";
import {EmGEMxTokenV2} from "./EmGEMxTokenV2.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract UpgradesTest is Test {
    function testUpgrade() public {
        MockV3Aggregator newOracle = new MockV3Aggregator(1000);

        // Deploy a transparent proxy with ContractA as the implementation and initialize it with 10
        address proxy = Upgrades.deployTransparentProxy(
            "EmGEMxToken.sol",
            msg.sender,
            abi.encodeCall(EmGEMxToken.initialize, (address(newOracle), "emGEMx", "emCH"))
        );

        // Get the instance of the contract
        EmGEMxToken instance = EmGEMxToken(proxy);

        // Get the implementation address of the proxy
        address implAddrV1 = Upgrades.getImplementationAddress(proxy);
        console.log("Implementation V1:", implAddrV1);

        // Get the admin address of the proxy
        address adminAddr = Upgrades.getAdminAddress(proxy);
        console.log("Admin:", adminAddr);

        // Ensure the admin address is valid
        assertFalse(adminAddr == address(0));

        // Log the initial value
        console.log("----------------------------------");
        console.log("Value before upgrade --> ", instance.name());
        console.log("----------------------------------");

        // Verify initial value is as expected
        assertEq(instance.name(), "emGEMx");

        // Upgrade the proxy
        Upgrades.upgradeProxy(proxy, "EmGEMxTokenV2.sol", "", msg.sender);

        // Get the new implementation address after upgrade
        address implAddrV2 = Upgrades.getImplementationAddress(proxy);
        console.log("Implementation V2:", implAddrV2);

        // Verify admin address remains unchanged
        assertEq(Upgrades.getAdminAddress(proxy), adminAddr);

        // Verify implementation address has changed
        assertFalse(implAddrV1 == implAddrV2);

        // Log and verify the updated value
        console.log("----------------------------------");
        console.log("Value after upgrade --> ", instance.name());
        console.log("----------------------------------");
        assertEq(instance.name(), "emGEMxV2");

        // set newly added variable and verify value.
        EmGEMxTokenV2 instanceV2 = EmGEMxTokenV2(address(instance));
        instanceV2.setAddedVariableValue(123);
        console.log("----------------------------------");
        console.log("Value of added variable after calling new functionality --> ", instanceV2.getAddedVariableValue());
        console.log("----------------------------------");
        assertEq(instanceV2.getAddedVariableValue(), 123);
    }
}
