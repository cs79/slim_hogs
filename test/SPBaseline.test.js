const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('SPBaseline', () => {
  let wallet;       // our default transactor
  let walletTo;     // another address that can receive
  let SPBaseline;   // intermediate contract to deploy
  let deployedSPB;  // deployed baseline contract

  // variables for contract creation
  const cerc = "0xface16c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const dres = "0xface26c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const arbi = "0xface36c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const coll = 1000;          // collateral
  const lots = 1;             // lot size
  const spri = 100;           // strike
  const expr = 1650000000;    // expiry unix epoch
  const euro = true;          // European ?
  const ispt = false;         // put ?
  const isrq = false;         // request ?

  
  beforeEach(async () => {
    [wallet, walletTo] = await ethers.getSigners();
    SPBaseline = await ethers.getContractFactory('SPBaseline');
    deployedSPB = await SPBaseline.deploy();
    await deployedSPB.deployed();
  });


  it('logs the gas price of a Piggy creation', async () => {
    const tx = await (deployedSPB.createPiggy(cerc,
      dres,
      arbi,
      coll,
      lots,
      spri,
      expr,
      euro,
      ispt,
      isrq));
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for createPiggy: " + rcpt.gasUsed);
  });


  it('logs the gas price of a transferFrom', async () => {
    await (deployedSPB.createPiggy(cerc,
      dres,
      arbi,
      coll,
      lots,
      spri,
      expr,
      euro,
      ispt,
      isrq));

    const testTokenId = await (deployedSPB.tokenId());
    const tx2 = await (deployedSPB.transferFrom(wallet.address, walletTo.address, testTokenId));
    const rcpt = await (tx2.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for transferFrom: " + rcpt.gasUsed);
  });

  it('logs the gas price of a reclaimAndBurn', async () => {
    await (deployedSPB.createPiggy(cerc,
      dres,
      arbi,
      coll,
      lots,
      spri,
      expr,
      euro,
      ispt,
      isrq));

    const testTokenId = await (deployedSPB.tokenId());
    const tx2 = await (deployedSPB.reclaimAndBurn(testTokenId));
    const rcpt = await (tx2.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for reclaimAndBurn: " + rcpt.gasUsed);
  });

  // it('logs the gas price of a settlePiggy', async () => {
  //   await (deployedSPB.createPiggy(cerc,
  //     dres,
  //     arbi,
  //     coll,
  //     lots,
  //     spri,
  //     expr,
  //     euro,
  //     ispt,
  //     isrq));
  //
  //   const testTokenId = await (deployedSPB.tokenId());
  //   const tx2 = await (deployedSPB.settlePiggy(testTokenId));
  //   const rcpt = await (tx2.wait());
  //   // console.log("rcpt: ");
  //   // console.log(rcpt);
  //   console.log("Gas used for settlePiggy: " + rcpt.gasUsed);
  // });

  // it('logs the gas price of a claimPayout', async () => {
  //   await (deployedSPB.createPiggy(cerc,
  //     dres,
  //     arbi,
  //     coll,
  //     lots,
  //     spri,
  //     expr,
  //     euro,
  //     ispt,
  //     isrq));
  //
  //   const testTokenId = await (deployedSPB.tokenId());
  //   const tx2 = await (deployedSPB.claimPayout(testTokenId, 50));
  //   const rcpt = await (tx2.wait());
  //   // console.log("rcpt: ");
  //   // console.log(rcpt);
  //   console.log("Gas used for claimPayout: " + rcpt.gasUsed);
  // });


  // need to write gas costs tests for the following in
  // SPBaseline.sol CONTRACT:
  // transferFrom - DONE
  // reclaimAndBurn - DONE
  // settlePiggy
  // claimPayout
  
});
