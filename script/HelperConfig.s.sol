// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**
 * @title Helper Config for Deployments
 *  - This will be used to deploy Mocks when we are on local anvil chain
 *  - Keep track of contract addresses across different chains
 * @author Soumil Vavikar
 * @notice NA
 */
contract HelperConfig is Script {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    /**
     * This struct will hold all the network configs required for the smart contract to function as needed.
     */
    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 vrfGasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    // Constant for sepolia chain id
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    // Constant for Ethereum Mainnet
    uint8 public constant MAINNET_CHAIN_ID = 1;

    /**
     * This object will hold the active network configurations
     */
    NetworkConfig public activeNetworkConfig;

    /**
     * Constructor to setup the activeNetworkConfig object
     */
    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else if (block.chainid == MAINNET_CHAIN_ID) {
            // activeNetworkConfig = getMainnetETHConfig();
        } else {
            activeNetworkConfig = createOrGetAnvilETHConfig();
        }
    }

    /**
     * This function will setup the network configurations for sepolia test net
     */
    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 0, // If left as 0, our scripts will create one!
                vrfGasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                interval: 30, // 30 seconds
                enteranceFee: 0.01 ether,
                callbackGasLimit: 500000, // 500,000 gas
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    /**
     * This function will setup the network configurations for local anvil chain
     *  - Here we will deploy the mocks
     *  - Return the mock contracts address
     */
    function createOrGetAnvilETHConfig() public returns (NetworkConfig memory) {
        // If the address for priceFeed !=0, i.e. its created already, we should return that and not re-create it
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK
        );
        LinkToken link = new LinkToken();
        uint64 subscriptionId = vrfCoordinatorV2Mock.createSubscription();
        vm.stopBroadcast();

        return
            NetworkConfig({
                subscriptionId: subscriptionId, // If left as 0, our scripts will create one!
                vrfGasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                interval: 30, // 30 seconds
                enteranceFee: 0.01 ether,
                callbackGasLimit: 500000, // 500,000 gas
                vrfCoordinator: address(vrfCoordinatorV2Mock), // Address of the mock vrfcoordinator mock,
                link: address(link)
            });
    }
}
