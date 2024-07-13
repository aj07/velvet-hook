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

contract PredictionMarket is Ownable {
    using PoolIdLibrary for PoolKey;

    IPoolManager public poolManager;
    PredictionMarketHook public predictionMarketHook;
    ERC20 public usdc;
    Token public yesToken;
    Token public noToken;

    event MarketCreated(PoolKey poolKey, PoolId poolId);

    PoolKey public poolKey; // Declare the poolKey as a state variable

    constructor(
        IPoolManager _poolManager,
        PredictionMarketHook _predictionMarketHook,
        ERC20 _usdc
    ) Ownable(msg.sender) {
        poolManager = _poolManager;
        predictionMarketHook = _predictionMarketHook;
        usdc = _usdc;
    }

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
        uint160 sqrtPriceX96 = 4295128739; // Equivalent to sqrt(1) in Q64.96 format
        poolManager.initialize(poolKey, sqrtPriceX96, "");
        emit MarketCreated(poolKey, poolId);
    }

    function buyYesToken(uint256 amountUSDC) external {
        usdc.transferFrom(
            msg.sender,
            address(predictionMarketHook),
            amountUSDC
        );
        PoolId poolId = poolKey.toId();
        predictionMarketHook.updateYesTokenBalance(
            msg.sender,
            poolId,
            amountUSDC
        );
    }

    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    function buyNoToken(uint256 amountUSDC) external {
        usdc.transferFrom(
            msg.sender,
            address(predictionMarketHook),
            amountUSDC
        );
        PoolId poolId = poolKey.toId();
        predictionMarketHook.updateNoTokenBalance(
            msg.sender,
            poolId,
            amountUSDC
        );
    }

    function resolveMarket(
        PoolKey calldata key,
        bool outcome
    ) external onlyOwner {
        predictionMarketHook.resolveMarket(key, outcome);
    }
}
