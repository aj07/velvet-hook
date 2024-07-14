// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {PredictionMarketHook} from "../src/PredictionMarketHook.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Token} from "../src/Token.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";

contract PredictionMarketTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    PredictionMarket public market;
    PredictionMarketHook public hook;
    Token public usdc;
    Token public yesToken;
    Token public noToken;

    address public user = address(1);
    address public user2 = address(2);
    address public user3 = address(3);

    /**
     * @dev Sets up the test environment, deploying the necessary contracts, minting tokens, and initializing the market.
     */
    function setUp() public {
        // Creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
                    Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );

        // Set up the USDC token
        usdc = new Token("USD Coin", "USDC");
        usdc.mint(user, 10000000000 * 1e18);
        usdc.mint(user2, 10000000000 * 1e18);
        usdc.mint(user3, 10000000000 * 1e18);
        usdc.mint(address(this), 100000000000 * 1e18); // Mint some USDC to the contract itself for providing liquidity

        address[8] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor())
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            usdc.approve(toApprove[i], Constants.MAX_UINT256);
        }

        deployCodeTo(
            "PredictionMarketHook.sol:PredictionMarketHook",
            abi.encode(manager, usdc),
            flags
        );
        hook = PredictionMarketHook(flags);

        // Deploy the prediction market contract
        market = new PredictionMarket(manager, hook, usdc);

        // Initialize the market
        market.initializeMarket();

        uint256 startTime = block.timestamp;
        uint256 duration = 30 days;

        yesToken = hook.yesToken();
        noToken = hook.noToken();

        // Initial mint just to start the pool
        yesToken.mint(address(this), 1 * 1e18);
        noToken.mint(address(this), 1 * 1e18);

        for (uint256 i = 0; i < toApprove.length; i++) {
            yesToken.approve(toApprove[i], Constants.MAX_UINT256);
            noToken.approve(toApprove[i], Constants.MAX_UINT256);
        }

        key = market.getPoolKey();

        // Provide full-range liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                1 ether,
                0
            ),
            ZERO_BYTES
        );

        hook.setMarketStartTime(startTime);
        hook.setMarketDuration(duration);
    }

    /**
     * @dev Tests setting the market duration.
     */
    function testSetMarketDuration() public {
        uint256 duration = 30 days;
        hook.setMarketDuration(duration);
        assertEq(hook.marketDuration(), duration);
    }

    /**
     * @dev Tests setting the market start time.
     */
    function testSetMarketStartTime() public {
        uint256 startTime = block.timestamp + 1 days;
        hook.setMarketStartTime(startTime);
        assertEq(hook.marketStartTime(), startTime);
    }

    /**
     * @dev Tests if the market is open during the expected time frame.
     */
    function testMarketIsOpen() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 duration = 30 days;

        hook.setMarketStartTime(startTime);
        hook.setMarketDuration(duration);

        assertEq(hook.isMarketOpen(), false);

        // Fast forward to the start time
        vm.warp(startTime);
        assertEq(hook.isMarketOpen(), true);

        // Fast forward to after the duration
        vm.warp(startTime + duration + 1);
        assertEq(hook.isMarketOpen(), false);
    }

    /**
     * @dev Tests buying YES tokens when the price is equal.
     */
    function testBuyYesTokenWhenPriceIsEqual() public {
        uint256 amountUSDC = 10 * 1e18;

        // Get the deployed YES tokens
        yesToken = hook.yesToken();

        // Approve USDC transfer
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // Buy YES tokens
        vm.prank(user);
        market.buyYesToken(amountUSDC);

        PoolId poolId = key.toId();

        uint256 yesBalance = hook.userYesBalances(poolId, user);
        console.log("yesBalance", yesBalance);
        assertEq(
            yesBalance,
            (amountUSDC * 1e18) / hook.calculateYesPrice(poolId),
            "YES token balance should be amountUSDC / YES price"
        );
    }

    /**
     * @dev Tests buying NO tokens when the price is equal.
     */
    function testBuyNoTokenWhenPriceIsEqual() public {
        uint256 amountUSDC = 1000 * 1e18;

        // Get the deployed NO tokens
        noToken = hook.noToken();

        // Approve USDC transfer
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // Buy NO tokens
        vm.prank(user);
        market.buyNoToken(amountUSDC);

        PoolId poolId = key.toId();
        uint256 noBalance = hook.userNoBalances(poolId, user);
        console.log("noBalance", noBalance);
        assertEq(
            noBalance,
            (amountUSDC * 1e18) / hook.calculateNoPrice(poolId),
            "NO token balance should be amountUSDC / NO price"
        );
    }

    /**
     * @dev Tests resolving the market.
     */
    function testResolveMarket() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        hook.setMarketStartTime(startTime);
        hook.setMarketDuration(duration);

        // Fast forward to after the duration
        vm.warp(startTime + duration + 1);

        PoolId poolId = market.getPoolKey().toId();
        market.resolveMarket(market.getPoolKey(), true);

        assertEq(hook.marketResolved(poolId), true);
        assertEq(hook.marketOutcome(poolId), true);
    }

    /**
     * @dev Tests claiming the reward.
     */
    function testClaimReward() public {
        testBuyYesTokenWhenPriceIsEqual();

        uint256 startTime = hook.marketStartTime();
        uint256 duration = hook.marketDuration();

        vm.warp(startTime + duration + 1);

        PoolId poolId = market.getPoolKey().toId();
        hook.resolveMarket(market.getPoolKey(), true);

        uint256 initialBalance = usdc.balanceOf(user);

        vm.prank(user);
        hook.claimReward(market.getPoolKey(), user);

        uint256 finalBalance = usdc.balanceOf(user);
        assertGt(finalBalance, initialBalance);
    }

    /**
     * @dev Tests buying tokens and claiming the reward after market resolution.
     */
    function testBuyAndClaimAfterMarketResolution() public {
        uint256 amountUSDC = 100 * 1e18;

        // Approve USDC transfer for user
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // User buys YES tokens
        vm.prank(user);
        market.buyYesToken(amountUSDC);

        PoolId poolId = key.toId();

        uint256 yesBalanceUser = hook.userYesBalances(poolId, user);
        assertGt(yesBalanceUser, 0, "User should have YES tokens");

        uint256 startTime = hook.marketStartTime();
        uint256 duration = hook.marketDuration();
        vm.warp(startTime + duration + 1);

        hook.resolveMarket(market.getPoolKey(), true);

        uint256 initialBalance = usdc.balanceOf(user);

        vm.prank(user);
        hook.claimReward(market.getPoolKey(), user);

        uint256 finalBalance = usdc.balanceOf(user);
        assertGt(finalBalance, initialBalance, "User should receive rewards");
    }

    /**
     * @dev Tests user2 investing in both YES and NO tokens and claiming rewards.
     */
    function test_User2InvestsInYesAndNoTokens() public {
        uint256 amountUSDC = 100 * 1e18;
        uint256 tolerance = 1; // Tolerance value for rounding differences

        // Approve USDC transfer for user2
        vm.prank(user2);
        usdc.approve(address(market), amountUSDC * 2);

        uint256 initialYesTokenSupply = yesToken.totalSupply();
        uint256 initialNoTokenSupply = noToken.totalSupply();

        // User2 buys YES tokens
        vm.prank(user2);
        market.buyYesToken(amountUSDC);

        PoolId poolId = key.toId();

        uint256 yesBalanceUser2 = hook.userYesBalances(poolId, user2);
        assertGt(yesBalanceUser2, 0, "User2 should have YES tokens");

        uint256 newYesTokenSupply = yesToken.totalSupply();
        uint256 expectedYesTokenSupplyIncrease = (amountUSDC * 1e18) /
            hook.calculateYesPrice(poolId);

        assertApproxEqRel(
            newYesTokenSupply,
            initialYesTokenSupply + expectedYesTokenSupplyIncrease,
            tolerance,
            "YES token supply should increase"
        );

        // User2 buys NO tokens
        vm.prank(user2);
        market.buyNoToken(amountUSDC);

        uint256 noBalanceUser2 = hook.userNoBalances(poolId, user2);
        assertGt(noBalanceUser2, 0, "User2 should have NO tokens");

        uint256 newNoTokenSupply = noToken.totalSupply();
        uint256 expectedNoTokenSupplyIncrease = (amountUSDC * 1e18) /
            hook.calculateNoPrice(poolId);

        assertGt(
            newNoTokenSupply,
            0,
            "NO token supply should increase"
        );

        uint256 user2USDCBalanceAfterBuys = usdc.balanceOf(user2);
        assertEq(
            user2USDCBalanceAfterBuys,
            10000000000 * 1e18 - amountUSDC * 2,
            "User2 USDC balance should decrease by the amount spent on YES and NO tokens"
        );

        // Fast forward to after the market duration
        uint256 startTime = hook.marketStartTime();
        uint256 duration = hook.marketDuration();
        vm.warp(startTime + duration + 1);

        // Resolve the market
        hook.resolveMarket(market.getPoolKey(), true);

        uint256 initialBalanceUser2 = usdc.balanceOf(user2);

        // User2 claims reward
        vm.prank(user2);
        hook.claimReward(market.getPoolKey(), user2);

        uint256 finalBalanceUser2 = usdc.balanceOf(user2);
        assertGt(
            finalBalanceUser2,
            initialBalanceUser2,
            "User2 should receive rewards"
        );

        uint256 yesTokenBalanceAfterClaim = hook.userYesBalances(poolId, user2);
        assertEq(
            yesTokenBalanceAfterClaim,
            0,
            "User2 YES token balance should be zero after claiming rewards"
        );

        uint256 noTokenBalanceAfterClaim = hook.userNoBalances(poolId, user2);
        assertEq(
            noTokenBalanceAfterClaim,
            noBalanceUser2,
            "User2 NO token balance should be unchanged after claiming rewards for YES tokens"
        );
    }

    /**
     * @dev Tests multiple users investing and claiming their share based on the market outcome.
     */
    function test_MultipleUsersInvestAndClaim() public {
        uint256 amountUSDCUser1 = 100 * 1e18;
        uint256 amountUSDCUser2 = 150 * 1e18;
        uint256 amountUSDCUser3 = 200 * 1e18;

        // Approve USDC transfer for all users
        vm.prank(user);
        usdc.approve(address(market), amountUSDCUser1);
        vm.prank(user2);
        usdc.approve(address(market), amountUSDCUser2);
        vm.prank(user3);
        usdc.approve(address(market), amountUSDCUser3);

        // User1 buys YES tokens
        vm.prank(user);
        market.buyYesToken(amountUSDCUser1);
        PoolId poolId = key.toId();
        uint256 yesBalanceUser1 = hook.userYesBalances(poolId, user);
        assertGt(yesBalanceUser1, 0, "User1 should have YES tokens");

        // User2 buys NO tokens
        vm.prank(user2);
        market.buyNoToken(amountUSDCUser2);
        uint256 noBalanceUser2 = hook.userNoBalances(poolId, user2);
        assertGt(noBalanceUser2, 0, "User2 should have NO tokens");

        // User3 buys YES and NO tokens
        vm.prank(user3);
        market.buyYesToken(amountUSDCUser3 / 2);
        vm.prank(user3);
        market.buyNoToken(amountUSDCUser3 / 2);
        uint256 yesBalanceUser3 = hook.userYesBalances(poolId, user3);
        uint256 noBalanceUser3 = hook.userNoBalances(poolId, user3);
        assertGt(yesBalanceUser3, 0, "User3 should have YES tokens");
        assertGt(noBalanceUser3, 0, "User3 should have NO tokens");

        // Fast forward to after the market duration
        uint256 startTime = hook.marketStartTime();
        uint256 duration = hook.marketDuration();
        vm.warp(startTime + duration + 1);

        // Resolve the market with YES as the outcome
        hook.resolveMarket(market.getPoolKey(), true);

        uint256 initialBalanceUser1 = usdc.balanceOf(user);
        uint256 initialBalanceUser2 = usdc.balanceOf(user2);
        uint256 initialBalanceUser3 = usdc.balanceOf(user3);

        // Users claim rewards
        vm.prank(user);
        hook.claimReward(market.getPoolKey(), user);
        vm.prank(user2);
        hook.claimReward(market.getPoolKey(), user2);
        vm.prank(user3);
        hook.claimReward(market.getPoolKey(), user3);

        uint256 finalBalanceUser1 = usdc.balanceOf(user);
        uint256 finalBalanceUser2 = usdc.balanceOf(user2);
        uint256 finalBalanceUser3 = usdc.balanceOf(user3);

        // Verify rewards are distributed based on YES outcome
        assertGt(
            finalBalanceUser1,
            initialBalanceUser1,
            "User1 should receive rewards"
        );
        assertEq(
            finalBalanceUser2,
            initialBalanceUser2,
            "User2 should not receive rewards for NO tokens"
        );
        assertGt(
            finalBalanceUser3,
            initialBalanceUser3,
            "User3 should receive rewards for YES tokens"
        );

        // Verify token balances after claiming rewards
        assertEq(
            hook.userYesBalances(poolId, user),
            0,
            "User1 YES token balance should be zero after claiming rewards"
        );
        assertEq(
            hook.userNoBalances(poolId, user2),
            noBalanceUser2,
            "User2 NO token balance should be unchanged after claiming rewards for YES tokens"
        );
        assertEq(
            hook.userYesBalances(poolId, user3),
            0,
            "User3 YES token balance should be zero after claiming rewards"
        );
        assertEq(
            hook.userNoBalances(poolId, user3),
            noBalanceUser3,
            "User3 NO token balance should be unchanged after claiming rewards for YES tokens"
        );
    }
}
