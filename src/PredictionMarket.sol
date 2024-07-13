// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PredictionMarketHook} from "./PredictionMarketHook.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Token} from "./Token.sol";

import "forge-std/console.sol";

/**
 * @title PredictionMarket
 * @dev A contract for creating and managing a prediction market using Uniswap v4.
 */
contract PredictionMarket is Ownable {
    using PoolIdLibrary for PoolKey;

    IPoolManager public poolManager;
    PredictionMarketHook public predictionMarketHook;
    ERC20 public usdc;
    Token public yesToken;
    Token public noToken;

    event MarketCreated(PoolKey poolKey, PoolId poolId);

    PoolKey public poolKey; // Declare the poolKey as a state variable

    /**
     * @dev Constructor to initialize the PredictionMarket contract.
     * @param _poolManager The address of the Uniswap v4 PoolManager contract.
     * @param _predictionMarketHook The address of the PredictionMarketHook contract.
     * @param _usdc The address of the USDC token contract.
     */
    constructor(
        IPoolManager _poolManager,
        PredictionMarketHook _predictionMarketHook,
        ERC20 _usdc
    ) Ownable(msg.sender) {
        poolManager = _poolManager;
        predictionMarketHook = _predictionMarketHook;
        usdc = _usdc;
    }

    /**
     * @dev Initializes the prediction market by deploying YES and NO tokens and setting up the Uniswap pool.
     */
    function initializeMarket() external onlyOwner {
        predictionMarketHook.deployTokens("YES Token", "YES", "NO Token", "NO");

        yesToken = predictionMarketHook.yesToken();
        noToken = predictionMarketHook.noToken();

        if (address(yesToken) > address(noToken)) {
            (yesToken, noToken) = (noToken, yesToken);
        }

        poolKey = PoolKey({
            currency0: Currency.wrap(address(yesToken)),
            currency1: Currency.wrap(address(noToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: predictionMarketHook
        });

        PoolId poolId = poolKey.toId();
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // Equivalent to sqrt(1) in Q64.96 format
        poolManager.initialize(poolKey, sqrtPriceX96, "");
        emit MarketCreated(poolKey, poolId);
    }

    /**
     * @dev Allows a user to buy YES tokens by spending USDC.
     * @param amountUSDC The amount of USDC to spend on buying YES tokens.
     */
    function buyYesToken(uint256 amountUSDC) external {
        usdc.transferFrom(
            msg.sender,
            address(predictionMarketHook),
            amountUSDC
        );
        predictionMarketHook.updateYesTokenBalance(
            msg.sender,
            poolKey,
            amountUSDC
        );
    }

    /**
     * @dev Returns the current pool key.
     * @return The current pool key.
     */
    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    /**
     * @dev Allows a user to buy NO tokens by spending USDC.
     * @param amountUSDC The amount of USDC to spend on buying NO tokens.
     */
    function buyNoToken(uint256 amountUSDC) external {
        usdc.transferFrom(
            msg.sender,
            address(predictionMarketHook),
            amountUSDC
        );
        predictionMarketHook.updateNoTokenBalance(
            msg.sender,
            poolKey,
            amountUSDC
        );
    }

    /**
     * @dev Resolves the market by setting the outcome.
     * @param key The pool key associated with the market.
     * @param outcome The outcome of the market (true for YES, false for NO).
     */
    function resolveMarket(
        PoolKey calldata key,
        bool outcome
    ) external onlyOwner {
        predictionMarketHook.resolveMarket(key, outcome);
    }
}