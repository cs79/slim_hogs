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


  // [DONE] - TODO: create a parallel test that checks proper functionality
  // e.g. piggyPrints[_fprint] == walletTo.address
  // might want to add a getter function to the contract for this purpose

  it('creates the correct keccak256 fingerprint for the input', async () => {
    let tx1 = await (deployedSPC.fingerprint(
        wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0));
    console.log("fingerprint tx val: " + tx1);
    // expect to equal ethers.utils.keccak256 of the same
    let wala_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(wallet.address), 32);
    let cerc_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(cerc), 32);
    let coll_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from("1000")), 32);
    let lots_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(1)), 32);
    let spri_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(10000)), 32);
    let expr_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(1650000000)), 32);
    let cldc_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(2)), 32);
    let euro_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(0)), 32);
    let ispt_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(0)), 32);
    let zero_bytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.BigNumber.from(0)), 32);

    // debug
    // console.log("wala_bytes: " + wala_bytes);
    // console.log("cerc_bytes: " + cerc_bytes);
    // console.log("coll_bytes: " + coll_bytes);
    // console.log("lots_bytes: " + lots_bytes);
    // console.log("spri_bytes: " + spri_bytes);
    // console.log("expr_bytes: " + expr_bytes);
    // console.log("cldc_bytes: " + cldc_bytes);
    // console.log("euro_bytes: " + euro_bytes);
    // console.log("ispt_bytes: " + ispt_bytes);
    // console.log("zero_bytes: " + zero_bytes);

    let arrayedBytes = ethers.utils.concat(
        [
        ethers.utils.arrayify(wala_bytes),
        ethers.utils.arrayify(cerc_bytes),
        ethers.utils.arrayify(coll_bytes),
        ethers.utils.arrayify(lots_bytes),
        ethers.utils.arrayify(spri_bytes),
        ethers.utils.arrayify(expr_bytes),
        ethers.utils.arrayify(cldc_bytes),
        ethers.utils.arrayify(euro_bytes),
        ethers.utils.arrayify(ispt_bytes),
        ethers.utils.arrayify(zero_bytes)
        ]
    );

    // console.log("arrayedBytes: " + arrayedBytes);

    let fprint = ethers.utils.keccak256(arrayedBytes);

    console.log("fprint from ethers: " + fprint)

    expect(tx1).to.equal(fprint);
  });

  it('creates a piggy and properly assigns owner', async () => {
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
    expect(await (deployedSPC.checkOwner(wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0))).to.equal(wallet.address);
  });


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
    ));
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for transferFrom: " + rcpt.gasUsed);
  });

  // [DONE] - TODO: create a functional test for transferFrom
  it('successfully changes the owner', async () => {
    await (deployedSPC.createPiggy(
        cerc,
        dres,
        arbi,
        coll,
        lots,
        spri,
        expr,
        euro,
        ispt,
        isrq));

    await (deployedSPC.transferFrom(
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
    ));

    expect(await (deployedSPC.checkOwner(wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0))).to.equal(walletTo.address);

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
        2,  // faked decimals
        euro,
        ispt,
        0   // acctCreatedNonce
    ))
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for reclaimAndBurn: " + rcpt.gasUsed);
  });

  // functional test for reclaimAndBurn
  it('should set the owner to zero address for burned token', async () => {
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

    expect(await (deployedSPC.checkOwner(wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0))).to.equal(wallet.address);

    // now burn the token and re-check the address
    await (deployedSPC.reclaimAndBurn(
        wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,  // faked decimals
        euro,
        ispt,
        0   // acctCreatedNonce
    ));

    expect(await (deployedSPC.checkOwner(wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,
        euro,
        ispt,
        0))).to.equal(ethers.constants.AddressZero);
  } )

  it('logs the gas price of a settlePiggy', async () => {
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

    let tx = await (deployedSPC.settlePiggy(
        wallet.address,
        cerc,
        coll,
        lots,
        spri,
        expr,
        2,  // faked decimals
        euro,
        ispt,
        0,  // acctCreatedNonce
        walletTo.address // mocked as holder
    ))
    const rcpt = await (tx.wait());
    // console.log("rcpt: ");
    // console.log(rcpt);
    console.log("Gas used for settlePiggy: " + rcpt.gasUsed);
  });

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
