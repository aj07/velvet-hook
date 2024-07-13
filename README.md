# Prediction Market on Uniswap V4

This project implements a decentralized prediction market using Uniswap V4 hooks. The prediction market allows users to buy "YES" and "NO" tokens based on their predictions about the outcome of an event. The prices of these tokens are dynamically determined based on supply and demand. Once the event's outcome is known, users can claim their rewards based on the tokens they hold.

## Overview

Prediction markets are financial markets where participants trade contracts whose payoff depends on the outcome of an uncertain future event. This prediction market is built using Uniswap V4 hooks, which allows for custom logic to be integrated into the Uniswap protocol. This approach leverages Uniswap's liquidity and pricing mechanisms while introducing custom behaviors for the prediction market.

### Key Features

- **Dynamic Pricing**: The prices of "YES" and "NO" tokens are determined by supply and demand, ensuring that the market reflects the collective sentiment of participants.
- **Custom Logic via Hooks**: The use of Uniswap V4 hooks allows for the implementation of custom behaviors, such as restricting swaps and managing token balances uniquely.
- **Decentralized and Trustless**: Built on the Ethereum blockchain, this prediction market is decentralized and trustless, with all interactions governed by smart contracts.

## Contracts

### PredictionMarket.sol

This contract initializes the prediction market, manages token purchases, and resolves the market. Key functions include:

- **initializeMarket**: Initializes the market by deploying the "YES" and "NO" tokens and setting up the Uniswap V4 pool.
- **buyYesToken**: Allows users to buy "YES" tokens using USDC.
- **buyNoToken**: Allows users to buy "NO" tokens using USDC.
- **resolveMarket**: Resolves the market based on the event's outcome.

### PredictionMarketHook.sol

This contract implements the custom logic for the prediction market using Uniswap V4 hooks. Key functions include:

- **deployTokens**: Deploys the "YES" and "NO" tokens.
- **updateYesTokenBalance**: Updates the balance of "YES" tokens for a user.
- **updateNoTokenBalance**: Updates the balance of "NO" tokens for a user.
- **resolveMarket**: Resolves the market and calculates the total supply of winning tokens.
- **claimReward**: Allows users to claim their rewards based on the tokens they hold.

### Why It's Different from Polymarket

Polymarket is a well-known prediction market platform that allows users to bet on the outcomes of various events. While Polymarket is a centralized platform, our implementation leverages the decentralized nature of Uniswap V4 and its innovative hook system. Here are the key differences:

1. **Decentralization**: Unlike Polymarket, which relies on a central authority to manage markets and outcomes, this implementation is entirely decentralized, with all operations handled by smart contracts on the Ethereum blockchain.

2. **Custom Hooks**: By using Uniswap V4 hooks, we can integrate custom logic directly into the liquidity pool operations. This allows for unique behaviors such as dynamic pricing and custom reward mechanisms that are not possible with standard Uniswap V3 or other decentralized exchanges.

3. **Dynamic Pricing**: The prices of "YES" and "NO" tokens are dynamically determined based on the liquidity and trading activity in the pool. This ensures that the token prices always reflect the current market sentiment.

4. **Automated Market Resolution**: The resolution of the market and distribution of rewards are automated through smart contracts, eliminating the need for manual intervention and reducing the risk of manipulation.

### Why Uniswap V4 and Not V2 or V3

Uniswap V4 introduces a powerful new feature called hooks, which are not available in Uniswap V2 or V3. Hooks allow developers to inject custom logic into the liquidity pool operations, enabling advanced functionalities such as dynamic pricing, custom fee structures, and bespoke trading rules. Here’s why this prediction market implementation is possible in Uniswap V4 but not in V2 or V3:

1. **Custom Hooks**: Uniswap V4's hook system allows for the creation of custom pre- and post-swap logic. This capability is crucial for implementing the dynamic pricing and market resolution mechanisms required for a prediction market. Uniswap V2 and V3 do not support such custom hooks, limiting their flexibility.

2. **Enhanced Flexibility**: The hooks in Uniswap V4 provide a level of flexibility that allows developers to create entirely new types of financial instruments and markets. This prediction market leverages hooks to manage token minting, burning, and price calculations based on market conditions, which would be impossible in the more rigid frameworks of V2 and V3.

3. **Direct Integration with Liquidity Pools**: Uniswap V4's hooks allow direct interaction with liquidity pool balances before and after swaps. This direct integration is essential for dynamically adjusting token prices and managing user balances in real-time, ensuring that the prediction market remains accurate and fair.

## Setup

### Prerequisites

- [Foundry](https://github.com/gakonst/foundry) - Ethereum development framework

### Installation

1. Clone the repository:

```
git clone the repo
cd {FolderName}
Install dependencies:

Copy code
forge install
Running Tests
Build the project:

Copy code
forge build
Run the tests:

Copy code
forge test
Test Cases
The test cases are implemented in test/PredictionMarketHook.t.sol. Here is a brief overview of the test cases:

testSetMarketDuration: Tests setting the market duration.
testSetMarketStartTime: Tests setting the market start time.
testMarketIsOpen: Tests if the market is open during the expected time frame.
testBuyYesTokenWhenPriceIsEqual: Tests buying "YES" tokens when the price is equal.
testBuyNoTokenWhenPriceIsEqual: Tests buying "NO" tokens when the price is equal.
testResolveMarket: Tests resolving the market.
testClaimReward: Tests claiming the reward.
testBuyAndClaimAfterMarketResolution: Tests buying tokens and claiming the reward after market resolution.
test_User2InvestsInYesAndNoTokens: Tests user2 investing in both "YES" and "NO" tokens and claiming rewards.
test_MultipleUsersInvestAndClaim: Tests multiple users investing and claiming their share based on the market outcome.
```
