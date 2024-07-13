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

contract PredictionMarketHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint256) public yesBalances;
    mapping(PoolId => uint256) public noBalances;
    mapping(PoolId => bool) public marketResolved;
    mapping(PoolId => bool) public marketOutcome;

    Token public yesToken;
    Token public noToken;

    // Mappings to track user balances and maintain a list of users
    mapping(PoolId => mapping(address => uint256)) public userYesBalances;
    mapping(PoolId => mapping(address => uint256)) public userNoBalances;
    mapping(PoolId => address[]) public yesTokenHolders;
    mapping(PoolId => address[]) public noTokenHolders;
    mapping(address => uint256) public liquidityPoints;

    // Time lock variables
    uint256 public marketStartTime;
    uint256 public marketDuration;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function deployTokens(
        string memory yesName,
        string memory yesSymbol,
        string memory noName,
        string memory noSymbol
    ) external {
        yesToken = new Token(yesName, yesSymbol);
        noToken = new Token(noName, noSymbol);
    }

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

    function setMarketDuration(uint256 _duration) external {
        marketDuration = _duration;
    }

    function setMarketStartTime(uint256 _startTime) external {
        marketStartTime = _startTime;
    }

    function isMarketOpen() public view returns (bool) {
        return
            block.timestamp >= marketStartTime &&
            block.timestamp <= marketStartTime + marketDuration;
    }

    function updateYesTokenBalance(
        address sender,
        PoolId poolId,
        uint256 amountUSDC
    ) public {
        require(isMarketOpen(), "Market is not open");

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

        // Debugging
        console.log("Updated Yes Token Balance");
        console.log("Sender:", sender);
        console.log("Amount USDC:", amountUSDC);
        console.log("Price:", price);
        console.log("Amount YES:", amountYes);
        console.log("yesBalances[poolId]:", yesBalances[poolId]);
    }

    function updateNoTokenBalance(
        address sender,
        PoolId poolId,
        uint256 amountUSDC
    ) public {
        require(isMarketOpen(), "Market is not open");

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

        // Debugging
        console.log("Updated No Token Balance");
        console.log("Sender:", sender);
        console.log("Amount USDC:", amountUSDC);
        console.log("Price:", price);
        console.log("Amount NO:", amountNo);
        console.log("noBalances[poolId]:", noBalances[poolId]);
    }

    function resolveMarket(PoolKey calldata key, bool outcome) external {
        PoolId poolId = key.toId();
        require(!marketResolved[poolId], "Market already resolved");
        marketResolved[poolId] = true;
        marketOutcome[poolId] = outcome;

        // Custom logic to distribute rewards
        _distributeRewards(poolId, outcome);
    }

    function _distributeRewards(PoolId poolId, bool outcome) internal {
        uint256 totalSupply = outcome
            ? yesBalances[poolId]
            : noBalances[poolId];
        require(totalSupply > 0, "No tokens to distribute");

        // uint256 usdcBalance = usdc.balanceOf(address(this));
        address[] memory accounts = _getAccounts(poolId, outcome);

        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 userBalance = outcome
                ? userYesBalances[poolId][account]
                : userNoBalances[poolId][account];
            uint256 reward = (userBalance * totalSupply) / totalSupply;

            if (reward > 0) {
                // usdc.transfer(account, reward);
            }
        }
    }

    function _getAccounts(
        PoolId poolId,
        bool outcome
    ) internal view returns (address[] memory) {
        return outcome ? yesTokenHolders[poolId] : noTokenHolders[poolId];
    }

    function _calculatePrice(
        uint256 balance,
        uint256 supply
    ) internal pure returns (uint256) {
        return
            (balance == 0 || supply == 0)
                ? 1e18 / 2
                : ((balance * 1e18) / supply);
    }

    function calculateYesPrice(PoolId poolId) public view returns (uint256) {
        uint256 yesBalance = yesBalances[poolId];
        uint256 noSupply = noBalances[poolId]; // Use noBalances instead of noSupply
        return _calculatePrice(yesBalance, noSupply);
    }

    function calculateNoPrice(PoolId poolId) public view returns (uint256) {
        uint256 noBalance = noBalances[poolId];
        uint256 yesSupply = yesBalances[poolId]; // Use yesBalances instead of yesSupply
        return _calculatePrice(noBalance, yesSupply);
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        // Calculate points based on the amount of liquidity added
        uint256 liquidityAdded = uint256(params.liquidityDelta);
        liquidityPoints[sender] += liquidityAdded; // Award 1 point for each wei of liquidity added
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        // Custom logic for after swap if needed
        return (BaseHook.afterSwap.selector, 0);
    }
}
