// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script, console} from "forge-std/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant PROOF_OF_RESERVE_MOCK = 10000 * 100000000; //10.000 in token decimals

    struct NetworkConfig {
        address esuOracle;
        bool deployOracleMock;
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
        sepoliaNetworkConfig =
            NetworkConfig({esuOracle: 0x8D26D407ebed4D03dE7c18f5Db913155a4D587AE, deployOracleMock: false});
    }

    function getFujiEthConfig() public pure returns (NetworkConfig memory fujiNetworkConfig) {
        fujiNetworkConfig =
            NetworkConfig({esuOracle: 0x8F1C8888fBcd9Cc5D732df1e146d399a21899c22, deployOracleMock: false});
    }

    function getAvalancheEthConfig() public pure returns (NetworkConfig memory avalancheNetworkConfig) {
        revert("Oracle feed address missing");
        avalancheNetworkConfig = NetworkConfig({esuOracle: address(0x0), deployOracleMock: false});
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        // no oracle on other chains than Avalanche
        mainnetNetworkConfig = NetworkConfig({esuOracle: address(0x0), deployOracleMock: false});
    }

    function getOrCreateAnvilEthConfig() public view returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.esuOracle != address(0)) {
            return activeNetworkConfig;
        }

        //MockV3Aggregator mock = new MockV3Aggregator(PROOF_OF_RESERVE_MOCK);
        //console.log("Anvil oracle mock:", address(mock));
        //anvilNetworkConfig = NetworkConfig({esuOracle: address(mock)});
        anvilNetworkConfig = NetworkConfig({esuOracle: address(0x0), deployOracleMock: true});
    }
}
