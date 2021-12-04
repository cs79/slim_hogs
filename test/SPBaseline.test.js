const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('SPBaseline', () => {
  let wallet;       // our default transactor
  let walletTo;     // another address that can receive
  let SPBaseline;   // intermediate contract to deploy
  let deployedSPB;  // deployed baseline contract

  // variables for contract creation
  var cerc = '0xface16c54eba05edebed44c4f986f49a5de55113';  // mocked address
  var dres = '0xface26c54eba05edebed44c4f986f49a5de55113';  // mocked address
  var arbi = '0xface36c54eba05edebed44c4f986f49a5de55113';  // mocked address
  var coll = 1000;          // collateral
  var lots = 1;             // lot size
  var spri = 100;           // strike
  var expr = 1650000000;    // expiry unix epoch
  var euro = true;          // European ?
  var ispt = false;         // put ?
  var isrq = false;         // request ?

  
  beforeEach(async () => {
    [wallet, walletTo] = await ethers.getSigners();
    SPBaseline = await ethers.getContractFactory('SPBaseline');
    deployedSPB = await SPBaseline.deploy();
    await deployedSPB.deployed();
  });


  it('logs the gas price of a Piggy creation', async () => {
    var tx = await (deployedSPB.createPiggy(cerc,
                                            dres,
                                            arbi,
                                            coll,
                                            lots,
                                            spri,
                                            expr,
                                            euro,
                                            ispt,
                                            isrq))
    var rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for createPiggy: " + rcpt.gasUsed);
  });

  // need to write gas costs tests for the following in
  // SPBaseline.sol CONTRACT:
  // transferFrom
  // reclaimAndBurn
  // settlePiggy
  // claimPayout
  
});
