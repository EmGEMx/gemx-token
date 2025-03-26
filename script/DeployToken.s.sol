// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//import {Script, console} from "forge-std/Script.sol"; // not recognized by VS Code
import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployOracleMock} from "./DeployOracleMock.s.sol";
import {EmGEMxToken} from "../src/EmGEMxToken.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

/**
 * @title Deployment script for the EmGEMx token contract
 * @dev Upgradable ERC 20 contract that contains a chain switch due to the fact that certain functionality (e.g. token max supply) should be limited to the parent chain (Avalanche C-Chain).
 */
contract DeployToken is Script {
    EmGEMxToken public token;

    function run() public returns (EmGEMxToken) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();

        (address esuOracle, bool deployOracleMock) = helperConfig.activeNetworkConfig();
        if (esuOracle == address(0x0) && deployOracleMock) {
            uint256 mockValue = helperConfig.PROOF_OF_RESERVE_MOCK();

            DeployOracleMock deployMock = new DeployOracleMock();
            MockV3Aggregator mock = deployMock.deploy(mockValue);
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
}
