// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

/**
 * @title This is the deploy raffle function to deploy the Raffle contract
 * @author Soumil Vavikar
 * @notice NA
 */
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 enteranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 vrfGasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activeNetworkConfig();

        // Check if we have subscription
        if (subscriptionId == 0) {
            // Create new subscription - vrf subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator
            );

            // Fund Subscription - vrf subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link
            );
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            enteranceFee,
            interval,
            vrfCoordinator,
            vrfGasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        // Add Consumer - i.e. add the raffle to the subscription
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId
        );

        return (raffle, helperConfig);
    }
}
