const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('SPChallenger', () => {
  let wallet;       // our default transactor
  let walletTo;     // another address that can receive
  let SPChallenger;   // intermediate contract to deploy
  let deployedSPC;  // deployed baseline contract

  // variables for contract creation
  const cerc = "0xface16c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const dres = "0xface26c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const arbi = "0xface36c54eba05edebed44c4f986f49a5de55113";  // mocked address
  const coll = 1000;          // collateral
  const lots = 1;             // lot size
  const spri = 10000;         // strike
  const expr = 1650000000;    // expiry unix epoch
  const euro = false;         // European ?
  const ispt = false;         // put ?
  const isrq = false;         // request ?

  
  beforeEach(async () => {
    [wallet, walletTo] = await ethers.getSigners();
    SPChallenger = await ethers.getContractFactory('SPChallenger');
    deployedSPC = await SPChallenger.deploy();
    await deployedSPC.deployed();
  });


  it('logs the gas price of a Piggy creation', async () => {
    const tx = await (deployedSPC.createPiggy(cerc,
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


  // TODO: create a parallel test that checks proper functionality
  // e.g. piggyPrints[_fprint] == walletTo.address
  // might want to add a getter function to the contract for this purpose
  it('logs the gas price of a transferFrom', async () => {
    await (deployedSPC.createPiggy(cerc,
      dres,
      arbi,
      coll,
      lots,
      spri,
      expr,
      euro,
      ispt,
      isrq));

    let tx = await (deployedSPC.transferFrom(
        wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0, // might break - seems OK actually
        walletTo.address
    ))
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for transferFrom: " + rcpt.gasUsed);
  });

  it('logs the gas price of a reclaimAndBurn', async () => {
    await (deployedSPC.createPiggy(cerc,
      dres,
      arbi,
      coll,
      lots,
      spri,
      expr,
      euro,
      ispt,
      isrq));

    let tx = await (deployedSPC.reclaimAndBurn(
        wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0 // might break
    ))
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for reclaimAndBurn: " + rcpt.gasUsed);
  });

//   it('logs the gas price of a settlePiggy', async () => {
//     await (deployedSPC.createPiggy(cerc,
//       dres,
//       arbi,
//       coll,
//       lots,
//       spri,
//       expr,
//       euro,
//       ispt,
//       isrq));

//     const testTokenId = await (deployedSPC.tokenId());
//     const tx2 = await (deployedSPC.settlePiggy(testTokenId));
//     const rcpt = await (tx2.wait());
//     // console.log("rcpt: ");
//     // console.log(rcpt);
//     console.log("Gas used for settlePiggy: " + rcpt.gasUsed);
//   });

//   it('logs the gas price of a claimPayout', async () => {
//     await (deployedSPC.createPiggy(cerc,
//       dres,
//       arbi,
//       coll,
//       lots,
//       spri,
//       expr,
//       euro,
//       ispt,
//       isrq));

//     // settle for our NFT so that wallet is owed some of cerc token
//     const testTokenId = await (deployedSPC.tokenId());
//     await(deployedSPC.settlePiggy(testTokenId));
//     const tx2 = await (deployedSPC.claimPayout(cerc, 100));
//     const rcpt = await (tx2.wait());

//     // TODO: add cost of PigCoin transfer() to this, to account
//     // for stubbed call:
//     console.log("Gas used for claimPayout: " + rcpt.gasUsed);
//   });


  // need to write gas costs tests for the following in
  // SPChallenger.sol CONTRACT:
  // transferFrom - DONE
  // reclaimAndBurn - DONE
  // settlePiggy - DONE
  // claimPayout - DONE
  
});
