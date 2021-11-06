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
});
