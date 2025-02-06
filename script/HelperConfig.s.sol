// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 18;
    int256 public constant PROOF_OF_RESERVE = 100_000;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address proofOfReserveOracle;
    }
    //uint256 deployerKey;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 43113) {
            activeNetworkConfig = getFujiEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            proofOfReserveOracle: address(0x0) //, deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFujiEthConfig() public view returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig = NetworkConfig({
            proofOfReserveOracle: address(0x0) //, deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.proofOfReserveOracle != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator proofOfReserveFeed = new MockV3Aggregator(PROOF_OF_RESERVE);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            proofOfReserveOracle: address(proofOfReserveFeed) //, deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
