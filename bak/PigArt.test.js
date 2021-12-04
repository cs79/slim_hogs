const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('PigArt', () => {
  let wallet;
  let walletTo;
  let token;
  let PigArt;

  beforeEach(async () => {
    // Get signers
    [wallet, walletTo] = await ethers.getSigners();
    PigArt = await ethers.getContractFactory('PigArt');
    token = await PigArt.deploy();
    await token.deployed();
  });

  it('Deployment', async () => {
    expect(await token.name()).to.equal('PigArt');
    expect(await token.symbol()).to.equal('PA');
  });

  it('Mint New Item', async () => {
    const itemId = await token.safeMint(walletTo.address);
    // console.log(itemId);
    // expect(await token.awardItem(wallet.address)).to.equal(1000);
  });

  //   it('Transfer emits event', async () => {
  //     await expect(token.transfer(walletTo.address, 7))
  //       .to.emit(token, 'Transfer')
  //       .withArgs(wallet.address, walletTo.address, 7);
  //   });

  //   it('Can not transfer above the amount', async () => {
  //     await expect(token.transfer(walletTo.address, 1007)).to.be.revertedWith(
  //       "VM Exception while processing transaction: reverted with reason string 'ERC20: transfer amount exceeds balance'"
  //     );
  //   });

  //   it('Send transaction changes receiver balance', async () => {
  //     await expect(() =>
  //       wallet.sendTransaction({ to: walletTo.address, value: 200 })
  //     ).to.changeBalance(walletTo, 200);
  //   });
});
