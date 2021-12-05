/**
 * SmartPiggies is an open source standard for
 * a free peer to peer global derivatives market
 *
 * Copyright (C) 2020, SmartPiggies inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.17;
pragma experimental ABIEncoderV2;

// using SafeMath from OpenZeppelin
import "./SafeMath.sol";

// !!!
// eliding Administered, Freezable, Serviced, UsingCooldown,
// UsingACompanion, UsingConstants for now - want baseline functions
// for gas cost comparison only
// !!!

// TODO:
// after porting over minimal baseline functionality,
// note locations in contract where ERC-20 is called
// rather than deploying additional test contracts, use
// PigCoin.sol + new tests to determine gas costs of those
// actions, and calculate the (perhaps slightly approximated)
// gas costs of making the external calls as though they
// were "part" of these functions (i.e. just add test gas
// costs together afterwards)

// TODO:
// for functionality used below that uses code from the
// companion contract, just inline it (e.g. for settlePiggy())

// TODO:
// also strip out any event emissions

// baseline contract here:
contract SPChallenger {
    using SafeMath for uint256;

    // maintain storage layout of SmartPiggies contract
    uint256 public cooldown;
    uint256 public bidCooldown;
    // address public companionAddress; // Helper contract address in SmartPiggies slot
    /**
    * CONSTANTS STORAGE LAYOUT
    */
    uint8 constant START_TIME     = 0;
    uint8 constant EXPIRY_TIME    = 1;
    uint8 constant START_PRICE     = 2;
    uint8 constant RESERVE_PRICE   = 3;
    uint8 constant TIME_STEP       = 4;
    uint8 constant PRICE_STEP      = 5;
    uint8 constant LIMIT_PRICE     = 6;
    uint8 constant ORACLE_PRICE    = 7;
    uint8 constant AUCTION_PREMIUM = 8;
    uint8 constant COOLDOWN        = 9;
    uint8 constant AUCTION_ACTIVE      = 0;
    uint8 constant BID_LIMIT_SET       = 1;
    uint8 constant BID_CLEARED         = 2;
    uint8 constant SATISFY_IN_PROGRESS = 3;
    // declare an enum for request type
    enum RequestType { Bid, Settlement }
    // define a byte 32 value for the failure of an external call
    bytes32 constant RTN_FALSE = bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);
    // define a byte 32 value for the success of an external call
    bytes32 constant TX_SUCCESS = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);
    // public unsigned 256 bit integer of a SmartPiggies token id number
    uint256 public tokenId;

    /**
    * Helps contracts guard against reentrancy attacks.
    * Author: Remco Bloemen, Eenae
    * N.B. If you mark a function `nonReentrant`, you should also
    * mark it `external`.
    */
    uint256 private _guardCounter;

    struct DetailAccounts {
        address writer;
        address holder;
        address collateralERC;
        address dataResolver;
        address arbiter;
        address writerProposedNewArbiter;
        address holderProposedNewArbiter;
    }

    struct DetailUints {
        uint256 collateral;
        uint256 lotSize;
        uint256 strikePrice;
        uint256 expiry;
        uint256 settlementPrice; //04.20.20 oil price is negative :9
        uint256 reqCollateral;
        uint256 arbitrationLock;
        uint256 writerProposedPrice;
        uint256 holderProposedPrice;
        uint256 arbiterProposedPrice;
        uint8 collateralDecimals;  // store decimals from ERC-20 contract
        uint8 rfpNonce;
    }

    struct BoolFlags {
        bool isRequest;
        bool isEuro;
        bool isPut;
        bool hasBeenCleared;  // flag whether the oracle returned a callback w/ price
        bool writerHasProposedNewArbiter;
        bool holderHasProposedNewArbiter;
        bool writerHasProposedPrice;
        bool holderHasProposedPrice;
        bool arbiterHasProposedPrice;
        bool arbiterHasConfirmed;
        bool arbitrationAgreement;
    }

    struct DetailAuction {
        uint256[10] details;
        address activeBidder;
        uint8 rfpNonce;
        bool[4] flags;
    }

    struct Piggy {
        DetailAccounts accounts; /// address details
        DetailUints uintDetails; /// number details
        BoolFlags flags; /// parameter switches
    }

    mapping (address => mapping(address => uint256)) private ERC20Balances;
    mapping (address => mapping(uint256 => uint256)) private bidBalances;
    mapping (address => uint256[]) private ownedPiggies;
    mapping (uint256 => uint256) private ownedPiggiesIndex;
    mapping (uint256 => Piggy) private piggies;
    mapping (uint256 => DetailAuction) private auctions;

    // new mapping required for tracking creation nonces

    // use this in conjunction w/ fingerprint() to get token identifier

    mapping (address => uint256) private acctCreatedNonces;

    // new mapping for piggies using challenger model
    mapping (bytes32 => address) private piggyPrints;

    // !!!
    // eliding all events for now
    // !!!

    constructor()
    public {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        // guard counter should be allowed to overflow
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "re-entered");
    }

    // double check the return type of sha3() to match this function's return
    function fingerprint(
        address _writer,
        address _collateralERC,
        uint256 _collateral,
        uint256 _lotSize,
        uint256 _strikePrice,
        uint256 _expiry,
        uint256 _collateralDecimals,
        bool _isEuro,
        bool _isPut,    
        uint256 _acctCreatedNonce
    )
        public
        pure
        returns(bytes32)
    {
        bytes32 fprint = keccak256(abi.encode(
            _writer,
            _collateralERC,
            _collateral,
            _lotSize,
            _strikePrice,
            _expiry,
            _collateralDecimals,
            _isEuro,
            _isPut,
            _acctCreatedNonce
        ));
        return fprint;
    }

    /// @notice Use this to create a new piggy non-fungible token.
    /// @dev Can be frozen, uses non-reentrant modifier
    /// @param _collateralERC The address of the reference ERC-20 token to be used as collateral
    /// @param _dataResolver The address of a service contract which will return the settlement price
    /// @param _arbiter The optional address used for arbitartion
    /// @param _collateral The amount of collateral for the piggy, denominated in units of the token
    /// at the `_collateralERC` address
    /// @param _lotSize A multiplier on the settlement price used to determine settlement claims
    /// @param _strikePrice The strike value of the piggy, in the same units as the settlement price
    /// @param _expiry The block height at which the option will expire
    /// @param _isEuro If true, the piggy can only be settled at or after `_expiry` is reached, else
    /// it can be settled at any time
    /// @param _isPut If true, the settlement claims will be calculated for a put piggy; else they
    /// will be calculated for a call piggy
    /// @param _isRequest If true, will create the token as an "RFP" / request for a particular piggy
    /// @return true is successful, else false
    function createPiggy(
        address _collateralERC,
        address _dataResolver,
        address _arbiter,
        uint256 _collateral,
        uint256 _lotSize,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isEuro,
        bool _isPut,
        bool _isRequest
    )
        external
        nonReentrant
        returns (bool)
    {
        require(
        _collateralERC != address(0) &&
        _dataResolver != address(0),
        "address cannot be 0"
        );
        require(
        _collateral != 0 &&
        _lotSize != 0 &&
        _strikePrice != 0,
        "param cannot be 0"
        );
        require(_expiry != 0 && block.timestamp < _expiry, "invalid expiry");

        require(
        _constructPiggy(
            _collateralERC,
            // _dataResolver,
            // _arbiter,
            _collateral,
            _lotSize,
            _strikePrice,
            _expiry,
            2, // hardcoding decimals as 2
            _isEuro,
            _isPut
            // _isRequest,
            // false
        ),
        "create failed"
        );

        // !!!
        // disabling ERC-20 collateral integration for now
        // could assume a constant cost for gas testing purposes
        // !!!
        /// *** warning untrusted function call ***
        /// if not an RFP, make sure the collateral can be transferred
        // if (!_isRequest) {
        // (bool success, bytes memory result) = attemptPaymentTransfer(
        //     _collateralERC,
        //     msg.sender,
        //     address(this),
        //     _collateral
        // );
        // bytes32 txCheck = abi.decode(result, (bytes32));
        // require(success && txCheck == TX_SUCCESS, "token xfer failed");
        // }

        return true;
    }

    // !!!
    // eliding splitPiggy() for now
    // !!!

    // alternative transferFrom() using fingerprint-based validation
    function transferFrom(
        address _writer,
        address _collateralERC,
        uint256 _collateral,
        uint256 _lotSize,
        uint256 _strikePrice,
        uint256 _expiry,
        uint256 _collateralDecimals,
        bool _isEuro,
        bool _isPut,    
        uint256 _acctCreatedNonce,
        address _to
    )
        public
    {
        bytes32 _fprint = fingerprint(
                _writer,
                _collateralERC,
                _collateral,
                _lotSize,
                _strikePrice,
                _expiry,
                _collateralDecimals,
                _isEuro,
                _isPut,
                _acctCreatedNonce
            );
        require(msg.sender == piggyPrints[_fprint], "only owner of fingerprinted token can xfer");
        _internalTransfer(_fprint, _to);
    }

    // function transferFrom(address _from, address _to, uint256 _tokenId)
    //     public
    // {
    //     require(msg.sender == piggies[_tokenId].accounts.holder, "sender must be holder");
    //     _internalTransfer(_from, _to, _tokenId);
    // }

    // !!!
    // eliding updateRFP - not testing RFPs for now
    // !!!


    // IF WE KEEP reclaimAndBurn:
    // mock ERC-20
    // remove event emission

    // alternative reclaimAndBurn() using fingerprint-based validation
    function reclaimAndBurn(
        address _writer,
        address _collateralERC,
        uint256 _collateral,
        uint256 _lotSize,
        uint256 _strikePrice,
        uint256 _expiry,
        uint256 _collateralDecimals,
        bool _isEuro,
        bool _isPut,
        uint256 _acctCreatedNonce
    )
        external
        nonReentrant
        returns (bool)
    {
        bytes32 _fprint = fingerprint(
                _writer,
                _collateralERC,
                _collateral,
                _lotSize,
                _strikePrice,
                _expiry,
                _collateralDecimals,
                _isEuro,
                _isPut,
                _acctCreatedNonce
            );
        require(msg.sender == piggyPrints[_fprint], "only owner of fingerprinted token can burn");
        
        // eliding auction / RFP flag checks as we do not currently have these mapped to fingerprints

        // assuming that this is not an RFP, and thus a valid call to reclaim collateral
        require(msg.sender == _writer, "sender must own collateral to be reclaimed");
        ERC20Balances[msg.sender][_collateralERC] = ERC20Balances[msg.sender][_collateralERC].add(_collateral);

        // also eliding remove / reset functionality - can reverse-engineer the approximate cost of these for corrected gas cost

        return true;
    }

    // function reclaimAndBurn(uint256 _tokenId)
    //     external
    //     nonReentrant
    //     returns (bool)
    // {
    //     require(msg.sender == piggies[_tokenId].accounts.holder, "sender must be holder");
    //     require(!auctions[_tokenId].flags[AUCTION_ACTIVE] || auctions[_tokenId].details[EXPIRY_TIME] < block.timestamp, "auction active");

    //     // reset bid if piggy was previously on bid and auction is restarted
    //     if (auctions[_tokenId].activeBidder != address(0)) {
    //     _reclaimBid(_tokenId, auctions[_tokenId].activeBidder);
    //     }

    //     if (!piggies[_tokenId].flags.isRequest) {
    //     require(msg.sender == piggies[_tokenId].accounts.writer, "sender must own collateral");

    //     // keep collateralERC address
    //     address collateralERC = piggies[_tokenId].accounts.collateralERC;
    //     // keep collateral
    //     uint256 collateral = piggies[_tokenId].uintDetails.collateral;

    //     ERC20Balances[msg.sender][collateralERC] = ERC20Balances[msg.sender][collateralERC].add(collateral);
    //     }
    //     // emit ReclaimAndBurn(_tokenId, msg.sender, piggies[_tokenId].flags.isRequest);
    //     // remove id from index mapping
    //     _removeTokenFromOwnedPiggies(piggies[_tokenId].accounts.holder, _tokenId);
    //     // burn the token (zero out storage fields)
    //     _resetPiggy(_tokenId);
    //     return true;
    // }

    // !!!
    // eliding all auction functionality for now
    // this could feasibly be performed off-chain if desired
    // (e.g. offchain order book with on-chain resolution)
    // !!!

    // !!!
    // eliding oracle interaction functionality for now
    // could mock this behavior if desired
    // !!!

    // !!! INLINED FROM COMPANION CONTRACT !!!

    /// @notice Use this to settle a piggy, calculates the payout if any.
    /// @dev Logic executes via delegate call
    /// @param _tokenId The id number of the piggy
    /// @return true is successful, else false
    function settlePiggy(uint256 _tokenId)
        public
        returns (bool)
    {
        require(msg.sender != address(0));
        require(_tokenId != 0, "tokenId cannot be zero");
        // require a settlement price to be returned from an oracle
        // for SPChallenger, mock this as we are not integrating an oracle
        uint256 fakePrice = 8000; // 20% drop from tested price of 10000
        piggies[_tokenId].uintDetails.settlementPrice = fakePrice;
        piggies[_tokenId].flags.hasBeenCleared = true;
        require(piggies[_tokenId].flags.hasBeenCleared, "piggy is not cleared");

        // check if arbitration is set, cooldown has passed
        if (piggies[_tokenId].accounts.arbiter != address(0)) {
        require(piggies[_tokenId].uintDetails.arbitrationLock <= block.timestamp, "arbiter set, locked for cooldown period");
        }

        uint256 payout;

        if(piggies[_tokenId].flags.isEuro) {
        require(piggies[_tokenId].uintDetails.expiry <= block.timestamp, "european must be expired");
        }
        payout = _calculateLongPayout(_tokenId);

        // set the balances of the two counterparties based on the payout
        address writer = piggies[_tokenId].accounts.writer;
        address holder = piggies[_tokenId].accounts.holder;
        address collateralERC = piggies[_tokenId].accounts.collateralERC;

        uint256 collateral = piggies[_tokenId].uintDetails.collateral;
        if (payout > collateral) {
        payout = collateral;
        }

        ERC20Balances[holder][collateralERC] = ERC20Balances[holder][collateralERC].add(payout);
        ERC20Balances[writer][collateralERC] = ERC20Balances[writer][collateralERC].add(collateral).sub(payout);

        // emit SettlePiggy(
        // _tokenId,
        // piggies[_tokenId].uintDetails.collateral.sub(payout),
        // payout.sub(fee),
        // msg.sender
        // );

        _removeTokenFromOwnedPiggies(holder, _tokenId);
        // clean up piggyId
        _resetPiggy(_tokenId);
        return true;
    }

    /// @notice Use this to withdraw any amount less than account balance (sends any reference ERC20 which the msg.sender is owed).
    /// @dev This is a pull-payment implementation, all users must amounts from the contract,
    /// uses non-reentrant modifier
    /// @param _paymentToken The ERC20 contract address
    /// @param _amount The amount to be withdrawn, less than or equal to available balance
    /// @return true is successful, else false
    function claimPayout(address _paymentToken, uint256 _amount)
        external
        nonReentrant
        returns (bool)
    {
        require(msg.sender != address(0));
        require(_amount != 0, "amount cannot be 0");
        require(_amount <= ERC20Balances[msg.sender][_paymentToken], "insufficient balance");
        ERC20Balances[msg.sender][_paymentToken] = ERC20Balances[msg.sender][_paymentToken].sub(_amount);

        // emit ClaimPayout(
        // msg.sender,
        // _amount,
        // _paymentToken
        // );

        // assume that transfer correctly took place on ERC-20

        // TODO: !!! NEED TO ACCOUNT FOR COST OF transfer() PER PigCoin CONTRACT HERE !!!

        // (bool success, bytes memory result) = address(_paymentToken).call(
        // abi.encodeWithSignature(
        //     "transfer(address,uint256)",
        //     msg.sender,
        //     _amount
        // )
        // );
        // bytes32 txCheck = abi.decode(result, (bytes32));
        // require(success && txCheck == TX_SUCCESS, "token xfer failed");

        return true;
    }

    // !!!
    // eliding all arbitration-related functionality for now
    // !!!

    // !!!
    // eliding all helper functions - not needed for gas testing
    // !!!

    /**
    * Internal functions
    */


    // alternative _constructPiggy using fingerprint;
    // same wrapper function / parameters

    function _constructPiggy(
        address _collateralERC,
        uint256 _collateral,
        uint256 _lotSize,
        uint256 _strikePrice,
        uint256 _expiry,
        uint256 _collateralDecimals,
        bool _isEuro,
        bool _isPut)
        public
        returns(bool)
        {
            // get the created nonce and corresponding NFT fingerprint
            address _writer = msg.sender;
            uint256 _acctNonce = acctCreatedNonces[_writer];
            acctCreatedNonces[_writer] = acctCreatedNonces[_writer].add(1);
            bytes32 _fprint = fingerprint(
                _writer,
                _collateralERC,
                _collateral,
                _lotSize,
                _strikePrice,
                _expiry,
                _collateralDecimals,
                _isEuro,
                _isPut,
                _acctNonce
            );
            // save the fingerprint in the ownership array
            piggyPrints[_fprint] = _writer;

            // if nothing reverted, return true indicator to wrapper
            return true;
        }


    // !!! INLINED FROM COMPANION CONTRACT !!!

    // function _constructPiggy(
    //     address _collateralERC,
    //     address _dataResolver,
    //     address _arbiter,
    //     uint256 _collateral,
    //     uint256 _lotSize,
    //     uint256 _strikePrice,
    //     uint256 _expiry,
    //     uint256 _splitTokenId,
    //     bool _isEuro,
    //     bool _isPut,
    //     bool _isRequest,
    //     bool _isSplit
    // )
    //     public
    //     returns (bool)
    // {
    //     // assuming all checks have passed:
    //     uint256 tokenExpiry;
    //     // tokenId should be allowed to overflow
    //     ++tokenId;

    //     // write the values to storage, including _isRequest flag
    //     Piggy storage p = piggies[tokenId];
    //     p.accounts.holder = msg.sender;
    //     p.accounts.collateralERC = _collateralERC;
    //     p.accounts.dataResolver = _dataResolver;
    //     p.accounts.arbiter = _arbiter;
    //     p.uintDetails.lotSize = _lotSize;
    //     p.uintDetails.strikePrice = _strikePrice;
    //     p.flags.isEuro = _isEuro;
    //     p.flags.isPut = _isPut;
    //     p.flags.isRequest = _isRequest;

    //     // conditional state variable assignments based on _isRequest:
    //     tokenExpiry = _expiry;
    //     if (_isRequest) {
    //     p.uintDetails.reqCollateral = _collateral;
    //     // p.uintDetails.collateralDecimals = _getERC20Decimals(_collateralERC);
    //     p.uintDetails.collateralDecimals = 2; // MOCKED FOR NOW
    //     p.uintDetails.expiry = tokenExpiry;
    //     } else if (_isSplit) {
    //     require(_splitTokenId != 0, "tokenId cannot be zero");
    //     require(!piggies[_splitTokenId].flags.isRequest, "token cannot be an RFP");
    //     require(piggies[_splitTokenId].accounts.holder == msg.sender, "only the holder can split");
    //     require(block.timestamp < piggies[_splitTokenId].uintDetails.expiry, "cannot split expired token");
    //     require(!auctions[_splitTokenId].flags[AUCTION_ACTIVE], "cannot split token on auction");
    //     require(!piggies[_splitTokenId].flags.hasBeenCleared, "cannot split cleared token");
    //     tokenExpiry = piggies[_splitTokenId].uintDetails.expiry;
    //     p.accounts.writer = piggies[_splitTokenId].accounts.writer;
    //     p.uintDetails.collateral = _collateral;
    //     p.uintDetails.collateralDecimals = piggies[_splitTokenId].uintDetails.collateralDecimals;
    //     p.uintDetails.expiry = tokenExpiry;
    //     } else {
    //     require(!_isSplit, "split cannot be true when creating a piggy");
    //     p.accounts.writer = msg.sender;
    //     p.uintDetails.collateral = _collateral;
    //     // p.uintDetails.collateralDecimals = _getERC20Decimals(_collateralERC);
    //     p.uintDetails.collateralDecimals = 2; // MOCKED FOR NOW
    //     p.uintDetails.expiry = tokenExpiry;
    //     }

    //     _addTokenToOwnedPiggies(msg.sender, tokenId);

    //     address[] memory a = new address[](4);
    //     a[0] = msg.sender;
    //     a[1] = _collateralERC;
    //     a[2] = _dataResolver;
    //     a[3] = _arbiter;

    //     uint256[] memory i = new uint256[](5);
    //     i[0] = tokenId;
    //     i[1] = _collateral;
    //     i[2] = _lotSize;
    //     i[3] = _strikePrice;
    //     i[4] = tokenExpiry;

    //     bool[] memory b = new bool[](3);
    //     b[0] = _isEuro;
    //     b[1] = _isPut;
    //     b[2] = _isRequest;

    //     // emit CreatePiggy(
    //     // a,
    //     // i,
    //     // b
    //     // );

    //     return true;
    // }

    // !!!
    // eliding _getERC20Decimals - mock if needed anywhere [IT IS]
    // !!!

    // alternative _internalTransfer using validated fingerprint
    function _internalTransfer(bytes32 _fprint, address _to)
        internal
    {
        piggyPrints[_fprint] = _to;
    }

    // internal transfer for transfers made on behalf of the contract
    // function _internalTransfer(address _from, address _to, uint256 _tokenId)
    //     internal
    // {
    //     require(_from == piggies[_tokenId].accounts.holder, "from must be holder");
    //     require(_to != address(0), "to cannot be 0");
    //     _removeTokenFromOwnedPiggies(_from, _tokenId);
    //     _addTokenToOwnedPiggies(_to, _tokenId);
    //     _clearHolderProposals(_tokenId);
    //     piggies[_tokenId].accounts.holder = _to;
    //     // emit TransferPiggy(_tokenId, _from, _to);
    // }

    // !!!
    // eliding all internal functions related to auctions for now
    // except _reclaimBig, used for reclaimAndBurn
    // may need to mock part of this related to collateralERC
    // !!!

    /// @dev internal function that will clear bid params, and return premium
    /// @param _tokenId The id number of the piggy
    function _reclaimBid(uint256 _tokenId, address recipient)
        internal
    {
        uint256 returnAmount;
        address collateralERC = piggies[_tokenId].accounts.collateralERC;

        //if RFP bidder gets reqested collateral back, holder gets reserve back
        if (piggies[_tokenId].flags.isRequest) {
        address bidder = auctions[_tokenId].activeBidder;
        // return requested collateral to filler
        returnAmount = piggies[_tokenId].uintDetails.reqCollateral;
        bidBalances[bidder][_tokenId] = 0;

        ERC20Balances[bidder][collateralERC] =
        ERC20Balances[bidder][collateralERC].add(returnAmount);

        // return reserve to holder
        address holder = piggies[_tokenId].accounts.holder;
        returnAmount = auctions[_tokenId].details[RESERVE_PRICE];
        bidBalances[holder][_tokenId] = 0;

        ERC20Balances[holder][collateralERC] =
        ERC20Balances[holder][collateralERC].add(returnAmount);
        }
        else {
        // refund the _reservePrice premium
        returnAmount = auctions[_tokenId].details[AUCTION_PREMIUM];
        bidBalances[recipient][_tokenId] = 0;

        ERC20Balances[recipient][collateralERC] =
        ERC20Balances[recipient][collateralERC].add(returnAmount);
        }

        // emit ReclaimBid(_tokenId, msg.sender);
        // clean up token bid
        _clearBid(_tokenId);
    }

    // !!! Not sure why this differs across base / companion
    //     this should be OK i think
    /// Determines the payout on a piggy given the settlement price
    function _calculateLongPayout(uint256 _tokenId)
        internal
        view
        returns (uint256 _payout)
    {
        bool _isPut = piggies[_tokenId].flags.isPut;
        uint256 _strikePrice = piggies[_tokenId].uintDetails.strikePrice;
        uint256 _exercisePrice = piggies[_tokenId].uintDetails.settlementPrice;
        uint256 _lotSize = piggies[_tokenId].uintDetails.lotSize;
        uint8 _decimals = piggies[_tokenId].uintDetails.collateralDecimals;

        if (_isPut && (_strikePrice > _exercisePrice)) {
        _payout = _strikePrice.sub(_exercisePrice);
        }
        if (!_isPut && (_exercisePrice > _strikePrice)) {
        _payout = _exercisePrice.sub(_strikePrice);
        }
        _payout = _payout.mul(10**uint256(_decimals)).mul(_lotSize).div(100);
        return _payout;
    }


    // MAY NOT NEED THIS ONE - mock / estimate gas cost separately
    /**
    * For clarity this is a private helper function to reuse the
    * repeated `transferFrom` calls to a token contract.
    *
    * The contract does still use address(ERC20Address).call("transfer(address,uint256)")
    * when the contract is making transfers from itself back to users.
    * `attemptPaymentTransfer` is used when collateral is approved by a user
    * in the specified token contract, and this contract makes a transfer on
    * the user's behalf, as `transferFrom` checks allowance before sending
    * and this contract does not make approval transactions.
    */
    function attemptPaymentTransfer(address _ERC20, address _from, address _to, uint256 _amount)
        private
        returns (bool, bytes memory)
    {
        /**
        * Check the return data because compound violated the ERC20 standard for
        * token transfers :9
        */
        // *** warning untrusted function call ***
        (bool success, bytes memory result) = address(_ERC20).call(
        abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            _from,
            _to,
            _amount
        )
        );
        return (success, result);
    }


    /// Keep track of which address owns which piggies.
    /// Used to return the array of owned piggies.
    function _addTokenToOwnedPiggies(address _to, uint256 _tokenId)
        private
    {
        ownedPiggiesIndex[_tokenId] = ownedPiggies[_to].length;
        ownedPiggies[_to].push(_tokenId);
    }

    /// Remove an owned piggy from the ownedPiggies array if the piggy
    /// changes ownership (a new holder is registered).
    function _removeTokenFromOwnedPiggies(address _from, uint256 _tokenId)
        private
    {
        uint256 lastTokenIndex = ownedPiggies[_from].length.sub(1);
        uint256 tokenIndex = ownedPiggiesIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
        uint256 lastTokenId = ownedPiggies[_from][lastTokenIndex];
        ownedPiggies[_from][tokenIndex] = lastTokenId;
        ownedPiggiesIndex[lastTokenId] = tokenIndex;
        }
        // old-style syntax (0.4.0) - cannot use
        // ownedPiggies[_from].length--;
    }

    /// Clear the bid auction parameters.
    /// This is a separate function as there may be multiple bids per auction.
    function _clearBid(uint256 _tokenId)
        private
    {
        auctions[_tokenId].details[ORACLE_PRICE] = 0;
        auctions[_tokenId].details[AUCTION_PREMIUM] = 0;
        auctions[_tokenId].details[COOLDOWN] = 0;
        auctions[_tokenId].activeBidder = address(0);
        auctions[_tokenId].rfpNonce = 0;
        auctions[_tokenId].flags[BID_CLEARED] = false;
    }

    /// Clear the auction parameters after the auction has been satisfied.
    function _clearAuctionDetails(uint256 _tokenId)
        private
    {
        auctions[_tokenId].details[START_TIME] = 0;
        auctions[_tokenId].details[EXPIRY_TIME] = 0;
        auctions[_tokenId].details[START_PRICE] = 0;
        auctions[_tokenId].details[RESERVE_PRICE] = 0;
        auctions[_tokenId].details[TIME_STEP] = 0;
        auctions[_tokenId].details[PRICE_STEP] = 0;
        auctions[_tokenId].details[LIMIT_PRICE] = 0;
        auctions[_tokenId].flags[AUCTION_ACTIVE] = false;
        auctions[_tokenId].flags[BID_LIMIT_SET] = false;
        _clearBid(_tokenId);
    }

    /// Clear arbiter proposal parameters
    function _clearHolderProposals(uint256 _tokenId)
        private
    {
        piggies[_tokenId].flags.holderHasProposedNewArbiter = false;
        piggies[_tokenId].accounts.holderProposedNewArbiter = address(0);
        piggies[_tokenId].uintDetails.holderProposedPrice = 0;
        piggies[_tokenId].flags.holderHasProposedPrice = false;
        piggies[_tokenId].uintDetails.arbiterProposedPrice = 0;
        piggies[_tokenId].flags.arbiterHasProposedPrice = false;
    }

    /// Clear all the piggy details after it completes its lifecycle.
    function _resetPiggy(uint256 _tokenId)
        private
    {
        delete piggies[_tokenId];
    }

}