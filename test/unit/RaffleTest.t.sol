// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

/**
 * @title This is a unit test class for Raffle contract
 * @author Soumil Vavikar
 * @notice NA
 */
contract RaffleTest is Test {
    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    // Adding some test data
    address public PLAYER = makeAddr("player");
    // Starting user balance
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint96 public constant LINK_BALANCE = 100 ether;

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 vrfGasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    LinkToken linkToken;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            enteranceFee,
            interval,
            vrfCoordinator,
            vrfGasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        linkToken = LinkToken(link);

        vm.deal(PLAYER, STARTING_USER_BALANCE);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            linkToken.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        linkToken.approve(vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
    }

    /**
     * This modifier sets the data to the state where the raffle time has passed
     */
    modifier raffleEnteredAndTimeHasPassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /**
     * This modifier sets the data to the state where the raffle time has NOT passed
     */
    modifier raffleEnteredAndTimeHasNotPassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();

        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleStartsInOpenState() public view {
        assert(Raffle.RaffleState.OPEN == raffle.getRaffleState());
    }

    /**
     * TESTING enterRaffle FUNCTION
     */
    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);

        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: enteranceFee}();
        // Assert
        address playerRecorded = raffle.getRafflePlayers()[0];
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsDrawingWinner()
        public
        raffleEnteredAndTimeHasPassed
    {
        // Arrange
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    /**
     * Tests for checkUpKeep
     */

    function testCheckUpKeepFalseIfItHasNoBalance() public {
        // Arrange
        // vm.warp is used to time-travel, i.e. add to block.timestamp
        vm.warp(block.timestamp + interval + 1);
        // vm.roll is used to mine the blocks
        vm.roll(block.number + 1);

        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepFalseIfRaffleNotOpen()
        public
        raffleEnteredAndTimeHasPassed
    {
        // Arrange
        raffle.performUpkeep("");

        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed()
        public
        raffleEnteredAndTimeHasNotPassed
    {
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood()
        public
        raffleEnteredAndTimeHasPassed
    {
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upKeepNeeded);
    }

    /**
     * PerformUpKeep Tests
     */

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        raffleEnteredAndTimeHasPassed
    {
        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsWhenCheckUpKeepIsFalse()
        public
        raffleEnteredAndTimeHasNotPassed
    {
        // Act
        uint256 currentBalance = 1e16;
        uint256 numPlayers = 1;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Here we are mentioning that we want to ensure that the revert is of a particular type + has all values returned as expected
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsWhenCheckUpKeepIsFalseOne()
        public
        raffleEnteredAndTimeHasNotPassed
    {
        // Act
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    /**
     * Testing the output of an event
     */
    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimeHasPassed
    {
        // Act
        vm.recordLogs(); // Saves all the logs in a data structure
        raffle.performUpkeep(""); // This will emit the requestId

        Vm.Log[] memory emittedLogs = vm.getRecordedLogs();

        // All the logs are stored as bytes32 in foundry
        // In performUpkeep - first emit would be from getRandomNumbers function call (vrfCoordinator) and the requestId is the 2nd emit. Hence index of [1]
        // In the index 1 of the emittedLogs for requestId, topics[0] is for the emit itself and topics[1] is the emitted requestid
        bytes32 requestId = emittedLogs[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(Raffle.RaffleState.DRAWING_WINNER == rState);
    }

    /**
     * Fulfilling Random Words
     * randomReqId - foundry will generate multiple random numbers and run the test multiple times
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomReqId
    ) public raffleEnteredAndTimeHasPassed {
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomReqId,
            address(raffle)
        );
    }

    /**
     * This test will do everything and will follow the happy path
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimeHasPassed
    {
        address expectedWinner = address(5);

        // Arrange
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i)); // similar to address of 1, 2, 3, and so on.
            hoax(player, STARTING_USER_BALANCE); // hoax = prank + deal 1 eth to the player
            raffle.enterRaffle{value: enteranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        // Act
        vm.recordLogs(); // Saves all the logs in a data structure
        raffle.performUpkeep(""); // This will emit the requestId
        Vm.Log[] memory emittedLogs = vm.getRecordedLogs();
        bytes32 requestId = emittedLogs[1].topics[1];

        console.log(uint256(requestId));

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = enteranceFee * (additionalEntrances + 1);
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
