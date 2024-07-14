# Prediction Market using V4 Custom Hooks

## Overview

Our project leverages V4 to create a sophisticated prediction market. Unlike traditional models, we employ a custom pricing algorithm to dynamically adjust the prices of "YES" and "NO" tokens based on their respective supplies and the total USDC balance in the pool. This ensures that prices remain positive and reflect the current market dynamics. The project also integrates with V4's `PoolManager` to manage the prediction market pools, providing a flexible and modular design that can be extended and customized by developers.

## Key Features

### Custom Curves

Our project replaces the v3 concentrated liquidity model with a custom pricing algorithm tailored for a prediction market. Instead of relying on the traditional x*y=k constant product formula, we employ a custom curve to dynamically adjust the prices of "YES" and "NO" tokens based on their respective supplies and the total USDC balance in the pool. This custom pricing algorithm ensures that the price of each token cannot reach zero and adjusts based on market conditions to maintain balance and fairness in the prediction market.

#### Implementation Details

- **Dynamic Pricing Calculation:** The prices of "YES" and "NO" tokens are recalculated based on their respective supplies and the USDC balance. This ensures that prices remain positive and reflect the current market dynamics.
- **Custom Hooks:** The custom curve is implemented using V4 hooks, specifically the `beforeSwap` and `afterSwap` hooks, to enforce the custom pricing rules and manage token balances within the pool.

### Pool Operators (Periphery)

Our contracts interact with the V4 `PoolManager` to manage the prediction market pools. The `PredictionMarket` contract serves as a pool operator, handling the creation and management of pools for the "YES" and "NO" tokens. It utilizes the `PoolManager` to initialize pools, update token balances, and resolve markets based on the outcomes.

#### Implementation Details

- **Pool Initialization:** The `PredictionMarket` contract calls the `PoolManager` to initialize pools with the necessary parameters, including the custom hooks for pricing and token management.
- **Liquidity Management:** While our specific use case does not involve traditional liquidity provisioning, the contracts are designed to interact with the `PoolManager` for adding and managing liquidity if needed in future expansions.

### Infrastructure / SDKs / Developer Tooling

Our project leverages the infrastructure provided by V4 to build a sophisticated prediction market. The use of custom hooks and the `PoolManager` enables developers to create and manage prediction markets with custom behaviors and pricing algorithms.

#### Implementation Details

- **Modular Design:** The contracts are designed with modularity in mind, allowing developers to extend and customize the prediction market functionality. The use of hooks provides a flexible way to add custom logic and integrate with third-party services.
- **Comprehensive Testing:** We have included a suite of unit tests to ensure the reliability and correctness of the contracts. These tests serve as a valuable resource for developers looking to understand and extend the prediction market's functionality.

## Detailed Breakdown of Features

### Custom Curves

- Implemented custom pricing algorithm for "YES" and "NO" tokens.
- Prices are recalculated based on the balance and supply of tokens, ensuring they remain positive and reflect market conditions.

### Pool Operators (Periphery)

- The `PredictionMarket` contract serves as the pool operator.
- Manages the creation and initialization of pools using the `PoolManager`.
- Handles the update of token balances and market resolution based on outcomes.

### Infrastructure / SDKs / Developer Tooling

- Leveraged V4 infrastructure to build the prediction market.
- Designed contracts with modularity for easy extension and customization.
- Provided comprehensive unit tests to validate functionality and serve as a resource for developers.

## Contracts

### PredictionMarket.sol

This contract initializes the prediction market, manages token purchases, and resolves the market. Key functions include:

- **initializeMarket:** Initializes the market by deploying the "YES" and "NO" tokens and setting up the V4 pool.
- **buyYesToken:** Allows users to buy "YES" tokens using USDC.
- **buyNoToken:** Allows users to buy "NO" tokens using USDC.
- **resolveMarket:** Resolves the market based on the event's outcome.

### PredictionMarketHook.sol

This contract implements the custom logic for the prediction market using V4 hooks. Key functions include:

- **deployTokens:** Deploys the "YES" and "NO" tokens.
- **updateYesTokenBalance:** Updates the balance of "YES" tokens for a user.
- **updateNoTokenBalance:** Updates the balance of "NO" tokens for a user.
- **resolveMarket:** Resolves the market and calculates the total supply of winning tokens.
- **claimReward:** Allows users to claim their rewards based on the tokens they hold.

## Why It's Different from Polymarket

Polymarket is a well-known prediction market platform that allows users to bet on the outcomes of various events. While Polymarket is a centralized platform, our implementation leverages the decentralized nature of V4 and its innovative hook system. Here are the key differences:

- **Decentralization:** Unlike Polymarket, which relies on a central authority to manage markets and outcomes, this implementation is entirely decentralized, with all operations handled by smart contracts on the Ethereum blockchain.
- **Custom Hooks:** By using V4 hooks, we can integrate custom logic directly into the liquidity pool operations. This allows for unique behaviors such as dynamic pricing and custom reward mechanisms that are not possible with standard V3 or other decentralized exchanges.
- **Dynamic Pricing:** The prices of "YES" and "NO" tokens are dynamically determined based on the liquidity and trading activity in the pool. This ensures that the token prices always reflect the current market sentiment.
- **Automated Market Resolution:** The resolution of the market and distribution of rewards are automated through smart contracts, eliminating the need for manual intervention and reducing the risk of manipulation.

## Why V4 and Not V2 or V3

V4 introduces a powerful new feature called hooks, which are not available in V2 or V3. Hooks allow developers to inject custom logic into the liquidity pool operations, enabling advanced functionalities such as dynamic pricing, custom fee structures, and bespoke trading rules. Here’s why this prediction market implementation is possible in V4 but not in V2 or V3:

- **Custom Hooks:** V4's hook system allows for the creation of custom pre- and post-swap logic. This capability is crucial for implementing the dynamic pricing and market resolution mechanisms required for a prediction market. V2 and V3 do not support such custom hooks, limiting their flexibility.
- **Enhanced Flexibility:** The hooks in V4 provide a level of flexibility that allows developers to create entirely new types of financial instruments and markets. This prediction market leverages hooks to manage token minting, burning, and price calculations based on market conditions, which would be impossible in the more rigid frameworks of V2 and V3.
- **Direct Integration with Liquidity Pools:** V4's hooks allow direct interaction with liquidity pool balances before and after swaps. This direct integration is essential for dynamically adjusting token prices and managing user balances in real-time, ensuring that the prediction market remains accurate and fair.

## Example Use Cases

### Prediction Market Creation

A developer can use our `PredictionMarket` contract to create a new prediction market, leveraging the custom curves for dynamic pricing of outcome tokens.

### Market Resolution and Reward Distribution

The contracts handle the resolution of the prediction market and distribution of rewards based on the outcome, using custom hooks to manage token balances and ensure fairness.

### Future Extensions

Developers can extend the functionality by adding new hooks or integrating with third-party services to enhance the prediction market features.

## Setup

### Prerequisites

- [Foundry](https://github.com/gakonst/foundry) - Ethereum development framework

### Installation

1. Clone the repository:
```
git clone the repo
cd {FolderName}
```

1. Install dependencies:
```
forge install

```

### Running Tests

1. Build the project:

```
forge build

```
1. Run the tests:

```
forge test
```

### Test Cases

The test cases are implemented in `test/PredictionMarketHook.t.sol`. Here is a brief overview of the test cases:

- **testSetMarketDuration**: Tests setting the market duration.
- **testSetMarketStartTime**: Tests setting the market start time.
- **testMarketIsOpen**: Tests if the market is open during the expected time frame.
- **testBuyYesTokenWhenPriceIsEqual**: Tests buying "YES" tokens when the price is equal.
- **testBuyNoTokenWhenPriceIsEqual**: Tests buying "NO" tokens when the price is equal.
- **testResolveMarket**: Tests resolving the market.
- **testClaimReward**: Tests claiming the reward.
- **testBuyAndClaimAfterMarketResolution**: Tests buying tokens and claiming the reward after market resolution.
- **test_User2InvestsInYesAndNoTokens**: Tests user2 investing in both "YES" and "NO" tokens and claiming rewards.
- **test_MultipleUsersInvestAndClaim**: Tests multiple users investing and claiming their share based on the market outcome.