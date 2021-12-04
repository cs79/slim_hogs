const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('PigCoin', () => {
  let wallet;
  let walletTo;
  let token;
  let PigCoin;

  beforeEach(async () => {
    [wallet, walletTo] = await ethers.getSigners();
    PigCoin = await ethers.getContractFactory('PigCoin');
    token = await PigCoin.deploy('1000');
    await token.deployed();
  });

  it('Assigns initial balance', async () => {
    expect(await token.balanceOf(wallet.address)).to.equal(1000);
  });

  it('Transfer emits event', async () => {
    await expect(token.transfer(walletTo.address, 7))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, walletTo.address, 7);
  });

  it('Can not transfer above the amount', async () => {
    await expect(token.transfer(walletTo.address, 1007)).to.be.revertedWith(
      "VM Exception while processing transaction: reverted with reason string 'ERC20: transfer amount exceeds balance'"
    );
  });

  it('Send transaction changes receiver balance', async () => {
    await expect(() =>
      wallet.sendTransaction({ to: walletTo.address, value: 200 })
    ).to.changeBalance(walletTo, 200);
  });

  it('logs the gas price of an ether transfer', async () => {
    const tx = await (wallet.sendTransaction({ to: walletTo.address, value: 200 }));
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for ether transfer: " + rcpt.gasUsed);
  });

  it('logs the gas price of an allowance approval', async () => {
    const tx = await (token.approve(walletTo.address, 100));
    const rcpt = await (tx.wait());
    console.log("Gas used for approval: " + rcpt.gasUsed);
  });

  it('logs the gas price of a transfer', async () => {
    const tx = await (token.transfer(walletTo.address, 50));
    const rcpt = await (tx.wait());
    console.log("Gas used for transfer: " + rcpt.gasUsed);
  });

  it('logs the gas price of a transferFrom', async () => {
    // console.log("Allowance: " + token.allowance(wallet, walletTo))
    token.approve(wallet.address, 100)
    const tx = await (token.transferFrom(wallet.address, walletTo.address, 50));
    const rcpt = await (tx.wait());
    console.log("Gas used for transferFrom: " + rcpt.gasUsed);
  });

});
