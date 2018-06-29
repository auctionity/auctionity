pragma solidity 0.4.23;

import "./AuctionitySafeMath.sol";

contract AuctionityTreasurerEth {
    address public owner;
    address public oracle;

    function lockDeposit(uint248 amount, address currentLeader) external returns (bool);
    function endorse(uint248 amount, address user) external returns (bool);
}

contract AuctionityAuctionEngPgEth {
    using AuctionitySafeMath for uint248;

    string public version = 'auction-eng-pg-eth-v0';

    address public owner;
    address public oracle;
    AuctionityTreasurerEth public auctionityTreasurerEth;

    address public auctionOwner;
    uint32 public startDate; // @dev int uint32, max timestamp = 4294967295 or 07 Feb 2106 07:28:15
    uint32 public endDate;
    uint32 public originalEndDate;
    uint248 public startAmount;

    uint24 public antiSnippingTriggerPeriod;
    uint16 public antiSnippingDuration;
    uint248 public bidIncremental;

    bytes public auctionEndVoucher;

    enum BidStatus {
        ACCEPTED,
        AMOUNT_TOO_LOW,
        LOCK_DEPOSIT_FAILED
    }

    uint248 public currentAmount;
    address public currentLeader;
    bytes32 public biddingHash;

    bool finished;

    // Error Codes
    enum Errors {
        INVALID_DATE_AT_CONTRACT_CREATION,
        AUCTION_OWNER_CAN_NOT_BID,
        AUCTION_IS_NOT_STARTED_YET,
        AUCTION_IS_ALREADY_ENDED,
        AUCTION_IS_NOT_FINISHED_YET,
        END_IS_ALREADY_CALLED,
        END_ENDORSE_FAILED
    }

    // events
    event LogNewAuction(uint248 startAmount, uint32 startDate, uint32 endDate, uint24 antiSnippingTriggerPeriod, uint24 antiSnippingDuration, uint248 bidIncremental);
    event LogAuctionFinished(address winner, uint248 amount, uint32 endDate, bytes32 biddingHash);
    event LogBid(uint248 amount, uint248 minimal, address indexed origin, bytes32 biddingParentHash, uint8 indexed status);
    event LogAntiSnippingTriggered(uint32 endDate);

    event LogAddAuctionEndVoucher(address auctionSC, address indexed auctionOwner, bytes hash);

    event LogError(uint8 indexed errorId);

    constructor (
        address _auctionityTreasurerEthSc,
        uint248 _startAmount,
        uint32 _startDate,
        uint32 _endDate,
        uint24 _antiSnippingTriggerPeriod, // @dev max 16777216 second
        uint16 _antiSnippingDuration, // @dev max 65536 second
        uint248 _bidIncremental
    ) public
    {
        if(_startDate >= _endDate || block.timestamp >= _endDate){
            emit LogError(uint8(Errors.INVALID_DATE_AT_CONTRACT_CREATION));
            return;
        }

        auctionOwner = msg.sender;
        startAmount = _startAmount;
        startDate = _startDate;
        endDate = _endDate;
        originalEndDate = _endDate;
        antiSnippingTriggerPeriod = _antiSnippingTriggerPeriod;
        antiSnippingDuration = _antiSnippingDuration;
        bidIncremental = _bidIncremental;

        auctionityTreasurerEth = AuctionityTreasurerEth(_auctionityTreasurerEthSc);
        owner = auctionityTreasurerEth.owner();
        oracle = auctionityTreasurerEth.oracle();

        biddingHash = bytes32(0);

        finished = false;

        emit LogNewAuction(_startAmount, _startDate, _endDate, _antiSnippingTriggerPeriod, _antiSnippingDuration, _bidIncremental);
    }

    // Modifier

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier isOracle() {
        require(msg.sender == oracle);
        _;
    }

    // Setter

    function setOracle(address _oracle)
    isOwner
    public
    {
        oracle = _oracle;
    }

    function setTreasurerSC(address _auctionityTreasurerEthSc)
    isOwner
    public
    {
        auctionityTreasurerEth = AuctionityTreasurerEth(_auctionityTreasurerEthSc);
    }

    /** Biding **/

    function bid(uint248 _amount)
    public
    returns (bool)
    {

        if(block.timestamp < startDate){
            emit LogError(uint8(Errors.AUCTION_IS_NOT_STARTED_YET));
            return false;
        }

        if(block.timestamp > endDate){
            emit LogError(uint8(Errors.AUCTION_IS_ALREADY_ENDED));
            return false;
        }

        if(msg.sender == auctionOwner){
            emit LogError(uint8(Errors.AUCTION_OWNER_CAN_NOT_BID));
            return false;
        }

        address _user = msg.sender;
        uint248 _minimal = getMinimalAmount();

        if (_amount < _minimal) {

            emit LogBid(_amount, _minimal, _user, biddingHash, uint8(BidStatus.AMOUNT_TOO_LOW));
            biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.AMOUNT_TOO_LOW)));
            return false;
        }

        if (!auctionityTreasurerEth.lockDeposit(_amount, currentLeader)) {
            emit LogBid(_amount, _minimal, _user, biddingHash, uint8(BidStatus.LOCK_DEPOSIT_FAILED));
            biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.LOCK_DEPOSIT_FAILED)));
            return false;
        }

        currentLeader = _user;
        currentAmount = _amount;
        _minimal = getMinimalAmount();

        emit LogBid(_amount, _minimal, _user, biddingHash, uint8(BidStatus.ACCEPTED));
        biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.ACCEPTED)));

        if (block.timestamp > endDate-antiSnippingTriggerPeriod) {
            endDate = uint32(block.timestamp + antiSnippingDuration);
            emit LogAntiSnippingTriggered(endDate);
        }

        return true;
    }

    /** Ending **/

    function end()
    public
    returns (bool)
    {
        if(block.timestamp <= endDate){
            emit LogError(uint8(Errors.AUCTION_IS_NOT_FINISHED_YET));
            return false;
        }

        if(finished){
            emit LogError(uint8(Errors.END_IS_ALREADY_CALLED));
            return false;
        }


        if (!auctionityTreasurerEth.endorse(currentAmount, currentLeader)) {
            emit LogError(uint8(Errors.END_ENDORSE_FAILED));
            return false;
        }

        finished = true;

        emit LogAuctionFinished(currentLeader, currentAmount, endDate, biddingHash);

        return true;
    }

    function setAuctionEndVoucher(bytes h) public isOracle
    {
        auctionEndVoucher = h;

        emit LogAddAuctionEndVoucher(this, auctionOwner, h);
    }

    // getter

    function getInfos() public view returns(
        address _auctionOwner,
        uint32 _startDate,
        uint32 _endDate,
        uint24 _antiSnippingTriggerPeriod,
        uint16 _antiSnippingDuration,
        uint256 _bidIncremental,
        uint256 _currentAmount,
        uint256 _minimalAmount,
        address _currentLeader,
        bytes32 _biddingHash,
        bool _finished
    )
    {
        return(
            auctionOwner,
            startDate,
            endDate,
            antiSnippingTriggerPeriod,
            antiSnippingDuration,
            bidIncremental,
            currentAmount,
            getMinimalAmount(),
            currentLeader,
            biddingHash,
            finished
        );
    }

    function getDates()
    public
    view
    returns(
        uint32 _startDate,
        uint32 _endDate,
        uint32 _originalEndDate
    ) {
        return(
            startDate,
            endDate,
            originalEndDate
        );
    }

    function getMinimalAmount()
    public
    view
    returns(
        uint248 _minimal
    ) {
        if(currentAmount > uint248(0))
        {
            _minimal = currentAmount.safeAdd248(bidIncremental);
            return;
        }

        _minimal = startAmount;
    }

    function getCurrentAmounts()
    public
    view
    returns(
        uint248 _current,
        uint248 _minimal
    ) {
        _current = currentAmount;
        _minimal = getMinimalAmount();
    }
}
