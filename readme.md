# Slim Hogs: Storage-optimized research for SmartPiggies

This repository contains a minimal subset of SmartPiggies functionality with baseline implementations tested against
a storage-optimized challenger implementation.

Writeup of research results is available at [this link](https://www.dropbox.com/s/7u46aj8x1wjftp2/Final%20Project%20Report%20-%20Alexander%20Lee%20and%20Edward%20Forgacs.pdf?dl=0).

## Contracts

Core functionality is implemented in `SPBaseline.sol` and `SPChallenger.sol`. `SafeMath.sol` is used for arithmetic operations in both contracts. `PigCoin.sol` is a standard ERC-20 contract used for calculating the gas cost of mocked calls in the alternative functionality implementations.

## Setup

Install dependencies

    yarn

## Test

Run the tests for core functionality coverage on the challenger contract, and gas costs on all contracts. Functional tests for
the baseline contract are covered in the [SmartPiggies repo](https://github.com/smartpiggies/smartpiggies).

    yarn test

## Additional development tools
### Size the contracts

Get the size of your contracts after compilation

    yarn contract-sizer

### Deploy a contract locally

In one terminal window, run

    npx hardhat node

In a separate window run:

    node scripts/sample-script.js

### HardHat Commands

Try running some of the following tasks:

    npx hardhat accounts
    npx hardhat compile
    npx hardhat clean
    npx hardhat test
    npx hardhat node
    node scripts/sample-script.js
    npx hardhat help

## Library Docs

* [HardHat](https://hardhat.org/getting-started/)
* [HardHat Waffle](https://hardhat.org/plugins/nomiclabs-hardhat-waffle.html)
* [OpenZepplin ERC20](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20)

