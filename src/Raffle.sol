// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A sample Rafle Contract
 * @author Soumil Vavikar
 * @notice This contract is for creating a sample raffle.
 * @dev Implements Chainlink VRFv2 (Verifiable Randomness Function)
 */
contract Raffle is VRFConsumerBaseV2 {
    /** Custom Errors - More gas efficient over require statement */
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 noOfPlayers,
        RaffleState raffleState
    );

    /** Type Declarations */
    /** Enums */
    enum RaffleState {
        OPEN,
        DRAWING_WINNER
    }

    /** State Variables / Data structures */
    // Constant for request confirmations needed.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    // Constant for Number of random numbers needed per call - we only need 1 random number, as we want to pick just one winner
    uint32 private constant NUM_WORDS = 1;

    // @dev the enterance fee to enter the lottery
    uint256 private immutable i_enteranceFee;
    // @dev duration of lottery in seconds.
    uint256 private immutable i_interval;
    // @dev VRFv2 Coordinator
    address private immutable i_vrfCoordinator;
    // @dev the VRFv2 Coordinator interface
    VRFCoordinatorV2Interface private immutable VRF_COORDINATOR;
    // @dev gaslane for VRFv2
    bytes32 private immutable i_vrfGasLane;
    // @dev subscriptionId for VRFv2
    uint64 private immutable i_vrfSubscriptionId;
    // @dev callback gas limit for VRFv2
    uint32 private immutable i_vrfCallbackGasLimit;

    // @dev will store the timestamp of when the last lottery winner was picked.
    uint256 private s_lastTimestamp;
    // @dev This has to be marked payable, as we will need to pay the winner when the lottery is drawn.
    address payable[] private s_players;
    // @dev Address of the most recent winner.
    address private s_mostRecentWinner;
    // @dev RaffleState variable to map to the enum
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /** The constructor */
    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 vrfGasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    )
        // As we used inheritance, we need to have the constructor of inherited class satisfied here like this.
        VRFConsumerBaseV2(vrfCoordinator)
    {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        // Setting the first instane of lastTimestamp to the time when the contract gets deployed.
        s_lastTimestamp = block.timestamp;
        // The VRFv2 Coordinator.
        i_vrfCoordinator = vrfCoordinator;
        i_vrfGasLane = vrfGasLane;
        i_vrfSubscriptionId = subscriptionId;
        i_vrfCallbackGasLimit = callbackGasLimit;

        VRF_COORDINATOR = VRFCoordinatorV2Interface(i_vrfCoordinator);

        // Default the RaffleState to OPEN
        s_raffleState = RaffleState.OPEN;
    }

    /**
     * This function will allow the users to enter the lottery.
     *  - We use external instead of public here as this function will not be called from within the contract + external is gas efficient.
     */
    function enterRaffle() external payable {
        // Checking if enough funds are sent to enter the raffle.
        if (msg.value < i_enteranceFee) {
            revert Raffle__NotEnoughETHSent();
        }

        // If the raffle state is not open, don't let anyone enter the raffle
        if (RaffleState.OPEN != s_raffleState) {
            revert Raffle__RaffleNotOpen();
        }

        // Adding the player to the list of players entering the raffle.
        s_players.push(payable(msg.sender));
        // As we have updated the storage variable/array here, we will emit an event
        emit EnteredRaffle(msg.sender);
    }

    /**
     * This is the automation trigger for the when the winner should be picked by the raffle.
     *
     * @dev This is the function that is called by the chainlink automation node to see if it's time to pick the winner by performing an upkeep.
     * The following conditions need to be met in order for the function to return true:
     *  - The time interval has passed
     *  - The RaffleState = OPEN
     *  - The contract has ETH, i.e. their are players in the Raffle
     *  - The subscription has been funded with LINK (This is implicit)
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        returns (
            // If we name our variables in the return section, we can directly use the variable defined here and don't need the return statement.
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool isRaffleOpen = RaffleState.OPEN == s_raffleState;
        // In order to check if there are players in the raffle, we can either to the below
        bool hasPlayers = 0 != s_players.length;
        // Or we can check if there is ETH in the contract by
        bool hasBalance = 0 < address(this).balance;
        // Best practice to check for both

        // Setting the condition to decide upKeepNeeded value
        upkeepNeeded =
            timeHasPassed &&
            isRaffleOpen &&
            hasPlayers &&
            hasBalance;

        // Having a return statement is a good practice - 0x0 - is a way to send empty bytes object
        return (upkeepNeeded, "0x0");
    }

    /**
     * This function will pick the winner automatically. This function will do it the following way:
     *  - Pick a random number.
     *  - Use the random number to pick a player.
     *  - Be automatically called (so we don't need to manually invoke this)
     */
    function performUpkeep(bytes calldata /* performData */) external {
        // Check if its time to do upkeep
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }

        // Changing the value of the current raffle state - so that no one can enter the raffle while we are picking the winner.
        s_raffleState = RaffleState.DRAWING_WINNER;

        // Step 1: Request the Random Number
        uint256 requestId = VRF_COORDINATOR.requestRandomWords(
            i_vrfGasLane,
            i_vrfSubscriptionId,
            REQUEST_CONFIRMATIONS,
            i_vrfCallbackGasLimit,
            NUM_WORDS
        );

        // This here is redundant - as the vrfCoordinator modules requestRandomNumber function emits the requestId
        // This is here ONLY for testing  the output for the events.
        // NOTE: We can never read the values emitted by the events in the smart contracts, however, we can get them in unit tests and ensure they are emitted as expected. 
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * This method will fulfill the random numbers generated.i.e. it will pick the winner from the list of players, and pay them the lottery winning amount
     *
     * @dev  This is the function that Chainlink VRF node calls to send the money to the random winner.
     * @param randomWords - random words
     */
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Step 2: Get the random number
        /** Checks */
        // As we requested for only one random number, we can get it from randomNumber[0]
        uint256 indexLocOfWinner = randomWords[0] % s_players.length;
        // Getting the address of the winner of the current lottery
        address payable winner = s_players[indexLocOfWinner];
        // Storing the address of the winner in the most recent winner
        s_mostRecentWinner = winner;

        /** Effects  */

        // Update the timestamp and reset the s_players array when the raffle completed, and we are good to start a new raffle
        s_lastTimestamp = block.timestamp;
        s_players = new address payable[](0);
        // Emit the event for the winner being picked.
        emit PickedWinner(winner);
        // Once the winner is picked, the amount is transferred, change the RaffleState back to OPEN
        s_raffleState = RaffleState.OPEN;

        /** Interactions */
        // Paying the winner, the lotter winning amount
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Functions */

    function getEnteranceFee() external view returns (uint256) {
        return i_enteranceFee;
    }

    function getRaffleState() view external returns (RaffleState) {
        return s_raffleState;
    }

    function getRafflePlayers() view external returns (address payable[] memory) {
        return s_players;
    }

    function getLastTimeStamp() view external returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() view external returns(address) {
        return s_mostRecentWinner;
    }
    
}
