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
import {Counter} from "../src/Counter.sol";
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
    PoolId poolId;

    address public user = address(1);
    address public user2 = address(2);
    address public user3 = address(3);

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
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

        deployCodeTo(
            "PredictionMarketHook.sol:PredictionMarketHook",
            abi.encode(manager),
            flags
        );
        hook = PredictionMarketHook(flags);

        // Set up the USDC token
        usdc = new Token("USD Coin", "USDC");
        usdc.mint(user, 10000000000 * 1e18);
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

        // Deploy the prediction market contract
        market = new PredictionMarket(manager, hook, usdc);

        // Initialize the market
        market.initializeMarket();

        uint256 startTime = block.timestamp;
        uint256 duration = 30 days;

        hook.setMarketStartTime(startTime);
        hook.setMarketDuration(duration);
    }

    function testSetMarketDuration() public {
        uint256 duration = 30 days;
        hook.setMarketDuration(duration);
        assertEq(hook.marketDuration(), duration);
    }

    function testSetMarketStartTime() public {
        uint256 startTime = block.timestamp + 1 days;
        hook.setMarketStartTime(startTime);
        assertEq(hook.marketStartTime(), startTime);
    }

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


    function testFirstBuyYesToken_WhenLiquidityIsZero() public {
        uint256 amountUSDC = 10 * 1e18;

        Token yesToken;

        // Get the deployed YES tokens
        yesToken = hook.yesToken();

        // Approve USDC transfer
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // Buy YES tokens
        vm.prank(user);
        market.buyYesToken(amountUSDC);

        key = market.getPoolKey();
        PoolId poolId = key.toId();

        uint256 yesBalance = hook.userYesBalances(poolId, user);
        console.log("yesBalance", yesBalance);
        assertEq(
            yesBalance,
            (amountUSDC * 2),
            "YES token balance should be 2 times of amountUSDC"
        );
    }

    function testFirstBuyNoToken_WhenLiquidityIsZero() public {
        uint256 amountUSDC = 1000 * 1e18;

        Token noToken;

        // Get the deployed NO tokens
        noToken = hook.noToken();

        // Approve USDC transfer
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // Buy YES tokens
        vm.prank(user);
        market.buyNoToken(amountUSDC);

        key = market.getPoolKey();
        PoolId poolId = key.toId();
        uint256 noBalance = hook.userNoBalances(poolId, user);
        console.log("noBalance", noBalance);
        assertEq(
            noBalance,
            (amountUSDC * 2),
            "NO token balance should be 2 times of amountUSDC"
        );
    }

    function testBuyYesToken_WhenPoolHasLiquidity_PriceShouldChange() public {
        testFirstBuyYesToken_WhenLiquidityIsZero();
        testFirstBuyNoToken_WhenLiquidityIsZero();
        uint256 amountUSDC = 10 * 1e18;

        Token yesToken;

        // Get the deployed YES tokens
        yesToken = hook.yesToken();

        // Approve USDC transfer
        vm.prank(user);
        usdc.approve(address(market), amountUSDC);

        // Buy YES tokens
        vm.prank(user);
        market.buyYesToken(amountUSDC);

        key = market.getPoolKey();
        PoolId poolId = key.toId();
        uint256 yesBalance = hook.userYesBalances(poolId, user);
        console.log("yesBalance", yesBalance);
        assertGt(yesBalance, 0, "YES token balance should be greater than 0");
        assertNotEq(
            yesBalance,
            (amountUSDC * 2),
            "YES token balance should not be equal 2 times of amountUSDC, it should vary"
        );
    }
}
