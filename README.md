# Proveably Random Raffle Contract

## About

This code is to generate a proveably random smart contract lottery.

## What would this project do?

1. User can enter by paying for a ticket.
    1.1. The ticket fees are going to go to the winner during the draw.
2. After X period of tim, the lottery will close and automatically draw a winner.
    2.1. This will happen programatically.

## How?

1. We will use `Solidity` and `Foundry` to build this application.
2. We will also leverage `Chainlink VRF` & `Chainlink Automation`.
    2.1. `Chainlink VRF` is used for randomness to select a winner.
    2.2. `Chainlink Automation` will help us have a time based trigger to pick a winner of the lottery.

## Events in Solidity

- Events are the way Solidity and the EVM provide developers with logging functionality used to write information to a data structure on the blockchain that lives outside of smart contracts' storage variables.
- Logs and events are stored in a data structure that is inaccessible to Smart Contracts, and hence it is cheaper to store information via events than storage variables.
- Frontend / offchain infrastructure can listen to the events.
- The events can be indexed so that they can searched faster when required or when they need to be listened to.
  - Indexed events are searchable.
- As a rule of thumb, everytime storage is updated, we should emit an event.
- More documentation can be found at: [Solidity Events](https://docs.alchemy.com/docs/solidity-events)

## CEI - Checks Effects, and Interactions

- Most important design pattern.
- The Checks-Effects-Interactions (CEI) pattern is a coding practice for smart contracts that helps prevent reentrancy attacks.
- The CEI pattern is also known as the tail call pattern in traditional concurrent programming.
- Some benefits of the CEI pattern include:
  - Reduced risk of reentrancy attacks
    - A reentrant call is treated the same as a call that is initiated after the first call is finished.
  - Limited attack surface
    - The CEI pattern limits the attack surface of a contract by making it impossible to perform multiple encapsulated function invocations.
  - Easy to apply
    - The CEI pattern can often be applied without changing any logic, simply by taking the functional code order into account.

## Install External Package

```shell
forge install transmissions11/solmate --no-commit
forge install ChainAccelOrg/foundry-devops --no-commit
```
