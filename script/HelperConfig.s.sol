// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script, console} from "forge-std/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant PROOF_OF_RESERVE_MOCK = 10_000;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address proofOfReserveOracle;
    }

    constructor() {
        if (block.chainid == 11155111) {
            // Ethereum Sepolia
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 43113) {
            // Avalanche Fuji Testnet
            activeNetworkConfig = getFujiEthConfig();
        } else if (block.chainid == 43114) {
            // Avalanche C-Chain Mainnet
            activeNetworkConfig = getAvalancheEthConfig();
        } else if (block.chainid == 1) {
            // Ethereum Mainnet
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        // no oracle on other chains than Avalanche
        sepoliaNetworkConfig = NetworkConfig({proofOfReserveOracle: 0x8D26D407ebed4D03dE7c18f5Db913155a4D587AE});
    }

    function getFujiEthConfig() public pure returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig = NetworkConfig({proofOfReserveOracle: 0x8F1C8888fBcd9Cc5D732df1e146d399a21899c22});
    }

    function getAvalancheEthConfig() public pure returns (NetworkConfig memory avalancheNetworkConfig) {
        revert("Feed address missing");
        avalancheNetworkConfig = NetworkConfig({proofOfReserveOracle: address(0x0)});
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        // no oracle on other chains than Avalanche
        mainnetNetworkConfig = NetworkConfig({proofOfReserveOracle: address(0x0)});
    }

    function getOrCreateAnvilEthConfig() public view returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.proofOfReserveOracle != address(0)) {
            return activeNetworkConfig;
        }

        //MockV3Aggregator mock = new MockV3Aggregator(PROOF_OF_RESERVE_MOCK);
        //console.log("Anvil oracle mock:", address(mock));
        //anvilNetworkConfig = NetworkConfig({proofOfReserveOracle: address(mock)});
        anvilNetworkConfig = NetworkConfig({proofOfReserveOracle: address(0x0)});
    }
}
