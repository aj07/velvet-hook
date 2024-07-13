// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Token} from "./Token.sol";

import "forge-std/Test.sol";

/**
 * @title PredictionMarketHook
 * @dev A contract to manage the prediction market using Uniswap v4 hooks.
 */
contract PredictionMarketHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint256) public yesBalances;
    mapping(PoolId => uint256) public noBalances;
    mapping(PoolId => bool) public marketResolved;
    mapping(PoolId => bool) public marketOutcome;

    Token public yesToken;
    Token public noToken;
    ERC20 public usdc;
    uint256 public totalSupply;

    // Mappings to track user balances and maintain a list of users
    mapping(PoolId => mapping(address => uint256)) public userYesBalances;
    mapping(PoolId => mapping(address => uint256)) public userNoBalances;
    mapping(PoolId => address[]) public yesTokenHolders;
    mapping(PoolId => address[]) public noTokenHolders;
    mapping(address => uint256) public liquidityPoints;

    // Time lock variables
    uint256 public marketStartTime;
    uint256 public marketDuration;

    /**
     * @dev Constructor to initialize the PredictionMarketHook contract.
     * @param _poolManager The address of the Uniswap v4 PoolManager contract.
     * @param _usdc The address of the USDC token contract.
     */
    constructor(IPoolManager _poolManager, ERC20 _usdc) BaseHook(_poolManager) {
        usdc = _usdc;
    }

    /**
     * @dev Deploys the YES and NO tokens for the prediction market.
     * @param yesName The name of the YES token.
     * @param yesSymbol The symbol of the YES token.
     * @param noName The name of the NO token.
     * @param noSymbol The symbol of the NO token.
     */
    function deployTokens(
        string memory yesName,
        string memory yesSymbol,
        string memory noName,
        string memory noSymbol
    ) external {
        yesToken = new Token(yesName, yesSymbol);
        noToken = new Token(noName, noSymbol);
    }

    /**
     * @dev Returns the permissions for the hooks.
     * @return The permissions for the hooks.
     */
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /**
     * @dev Initializes the market with zero balances and unresolved status.
     * @param key The pool key.
     * @return The selector of the function.
     */
    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160,
        bytes calldata
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        yesBalances[poolId] = 0;
        noBalances[poolId] = 0;
        marketResolved[poolId] = false;
        return BaseHook.beforeInitialize.selector;
    }

    /**
     * @dev Sets the duration of the market.
     * @param _duration The duration of the market.
     */
    function setMarketDuration(uint256 _duration) external {
        marketDuration = _duration;
    }

    /**
     * @dev Sets the start time of the market.
     * @param _startTime The start time of the market.
     */
    function setMarketStartTime(uint256 _startTime) external {
        marketStartTime = _startTime;
    }

    /**
     * @dev Checks if the market is open.
     * @return True if the market is open, false otherwise.
     */
    function isMarketOpen() public view returns (bool) {
        return
            block.timestamp >= marketStartTime &&
            block.timestamp <= marketStartTime + marketDuration;
    }

    /**
     * @dev Updates the YES token balance for a user.
     * @param sender The address of the user.
     * @param key The pool key.
     * @param amountUSDC The amount of USDC to spend on YES tokens.
     */
    function updateYesTokenBalance(
        address sender,
        PoolKey calldata key,
        uint256 amountUSDC
    ) public {
        require(isMarketOpen(), "Market is not open");
        PoolId poolId = key.toId();
        uint256 price = calculateYesPrice(poolId);
        require(price > 0, "Price must be greater than 0");
        uint256 amountYes = (amountUSDC * 1e18) / price;
        require(amountYes > 0, "Amount YES must be greater than 0");

        if (userYesBalances[poolId][sender] == 0) {
            yesTokenHolders[poolId].push(sender);
        }
        yesBalances[poolId] += amountYes;
        userYesBalances[poolId][sender] += amountYes;
        yesToken.mint(address(this), amountYes); // Mint to the pool
        donateTokensToPool(key, amountYes, 0); // Donate YES tokens to the pool
    }

    /**
     * @dev Updates the NO token balance for a user.
     * @param sender The address of the user.
     * @param key The pool key.
     * @param amountUSDC The amount of USDC to spend on NO tokens.
     */
    function updateNoTokenBalance(
        address sender,
        PoolKey calldata key,
        uint256 amountUSDC
    ) public {
        require(isMarketOpen(), "Market is not open");
        PoolId poolId = key.toId();
        uint256 price = calculateNoPrice(poolId);
        require(price > 0, "Price must be greater than 0");
        uint256 amountNo = (amountUSDC * 1e18) / price;
        require(amountNo > 0, "Amount NO must be greater than 0");

        if (userNoBalances[poolId][sender] == 0) {
            noTokenHolders[poolId].push(sender);
        }
        noBalances[poolId] += amountNo;
        userNoBalances[poolId][sender] += amountNo;
        noToken.mint(address(this), amountNo); // Mint to the pool
        donateTokensToPool(key, 0, amountNo); // Donate NO tokens to the pool
    }

    /**
     * @dev Donates tokens to the pool.
     * @param key The pool key.
     * @param amountYes The amount of YES tokens to donate.
     * @param amountNo The amount of NO tokens to donate.
     */
    function donateTokensToPool(
        PoolKey calldata key,
        uint256 amountYes,
        uint256 amountNo
    ) internal {
        yesToken.approve(address(poolManager), amountYes);
        noToken.approve(address(poolManager), amountNo);

        poolManager.donate(key, amountYes, amountNo, "");
    }

    /**
     * @dev Resolves the market with the given outcome.
     * @param key The pool key.
     * @param outcome The outcome of the market (true for YES, false for NO).
     */
    function resolveMarket(PoolKey calldata key, bool outcome) external {
        PoolId poolId = key.toId();
        require(!marketResolved[poolId], "Market already resolved");
        require(
            block.timestamp > marketStartTime + marketDuration,
            "Market duration not over"
        );
        marketResolved[poolId] = true;
        marketOutcome[poolId] = outcome;
        totalSupply = outcome ? yesBalances[poolId] : noBalances[poolId];
    }

    /**
     * @dev Claims the reward for a user based on the market outcome.
     * @param key The pool key.
     * @param _claimFor The address of the user claiming the reward.
     */
    function claimReward(PoolKey calldata key, address _claimFor) external {
        PoolId poolId = key.toId();
        require(marketResolved[poolId], "Market Not Resolved");
        require(totalSupply > 0, "No tokens to distribute");

        uint256 usdcBalance = usdc.balanceOf(address(this));

        bool outcome = marketOutcome[poolId];

        uint256 userBalance = outcome
            ? userYesBalances[poolId][_claimFor]
            : userNoBalances[poolId][_claimFor];
        uint256 reward = (userBalance * usdcBalance) / totalSupply;

        if (reward > 0) {
            usdc.transfer(_claimFor, reward);
            totalSupply -= userBalance;
        }

        if (outcome) userYesBalances[poolId][_claimFor] = 0;
        else userNoBalances[poolId][_claimFor] = 0;
    }

    /**
     * @dev Calculates the price based on balance and supply.
     * @param balance The balance of the token.
     * @param supply The supply of the token.
     * @return The calculated price.
     */
    function _calculatePrice(
        uint256 balance,
        uint256 supply
    ) internal pure returns (uint256) {
        return
            (balance == 0 || supply == 0)
                ? 1e18 / 2
                : ((balance * 1e18) / supply);
    }

    /**
     * @dev Calculates the price of YES tokens.
     * @param poolId The pool ID.
     * @return The calculated price of YES tokens.
     */
    function calculateYesPrice(PoolId poolId) public view returns (uint256) {
        uint256 yesBalance = yesBalances[poolId];
        uint256 noSupply = noBalances[poolId]; // Use noBalances instead of noSupply
        return _calculatePrice(yesBalance, noSupply);
    }

    /**
     * @dev Calculates the price of NO tokens.
     * @param poolId The pool ID.
     * @return The calculated price of NO tokens.
     */
    function calculateNoPrice(PoolId poolId) public view returns (uint256) {
        uint256 noBalance = noBalances[poolId];
        uint256 yesSupply = yesBalances[poolId]; // Use yesBalances instead of yesSupply
        return _calculatePrice(noBalance, yesSupply);
    }

    /**
     * @dev Reverts any swap attempts as swapping is not allowed in this market.
     */
    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external pure override returns (bytes4, BeforeSwapDelta, uint24) {
        revert("Swapping is not allowed in this market");
    }

    /**
     * @dev Reverts any swap attempts as swapping is not allowed in this market.
     */
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, int128) {
        revert("Swapping is not allowed in this market");
    }

    /**
     * @dev Awards liquidity points based on the amount of liquidity added.
     * @param sender The address of the user adding liquidity.
     * @param key The pool key.
     * @param params The liquidity parameters.
     * @param delta The balance delta.
     * @param data Additional data.
     * @return The selector of the function and the balance delta.
     */
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata data
    ) external override returns (bytes4, BalanceDelta) {
        // Calculate points based on the amount of liquidity added
        uint256 liquidityAdded = uint256(params.liquidityDelta);
        liquidityPoints[sender] += liquidityAdded; // Award 1 point for each wei of liquidity added
        return (BaseHook.afterAddLiquidity.selector, delta);
    }
}
