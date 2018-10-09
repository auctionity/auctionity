pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./SafeMath96.sol";
import "./SafeMath32.sol";
import "./AuctionityLibraryDecodeRawTx.sol";

contract AuctionityDataForAuction {
    address public owner;
    address public oracle;
    address public auctionityAuctionFactoryAddress;
    address public auctionityTreasurerAddress;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;

    address public clubSponsor;

    function decodeRawTxGetTransferInfo(
        bytes memory _signedRawTxTokenTransfer,
        uint8 _chainId,
        address _tokenContractAddress
    ) public returns (
        address _tokenContractAddress2,
        address _addressOriginalOwnerOfErc721,
        address _addressDeposit,
        uint _tokenId
    );
}

contract AuctionityTreasurerEth {
    function lockDeposit(uint256 _amount, address _currentLeader) external returns (bool);
    function endorse(uint256 _amount, address _user) external returns (bool);
}

contract AuctionityAuctionEngPgEth {
    using SafeMath for uint256;
    using SafeMath96 for uint96;
    using SafeMath32 for uint32;

    string public version = "auction-eng-pg-eth-v1";

    address public owner;
    address public oracle;
    address public auctionityAuctionFactoryAddress;
    AuctionityDataForAuction public auctionityDataForAuction;
    AuctionityTreasurerEth public auctionityTreasurerEth;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;


    bytes public signedRawTxTokenTransfer;
    bytes32 public tokenHash;
    address public contractDepositAddress;
    address public tokenContractAddress;
    uint256 public tokenId;

    address public auctionSeller;
    uint32 public startDate; // @dev int uint32, max timestamp = 4294967295 or 07 Feb 2106 07:28:15
    uint32 public endDate;
    uint32 public originalEndDate;
    uint256 public startAmount;

    enum auctionState {
        UNVERIFIED,
        VERIFIED,
        REFUSED,
        CLOSED
    }

    uint8 public state;

    uint24 public antiSnippingTriggerPeriod;
    uint16 public antiSnippingDuration;
    uint256 public bidIncremental;

    bytes public auctionEndVoucher;

    enum BidStatus {
        ACCEPTED,
        AMOUNT_TOO_LOW,
        LOCK_DEPOSIT_FAILED
    }

    uint256 public currentAmount;
    address public currentLeader;
    uint256 public blockNumberOfTheLastBidAccepted;
    bytes32 public biddingHash;

    // sponsor
    address public auctionSponsor;
    uint8 public auctionReward;
    uint8 public rewardClub = 20;
    uint8 public rewardAuction = 20;
    uint8 public rewardLastBid = 30;
    uint8 public rewardBid = 30;
    uint16 public maxReward = 200;
    uint16 public rewardsCount;

    address public clubSponsor;
    uint256 public sellerAmount;
    uint256 public rewardClubAmount;
    uint96 public rewardAuctionAmount;
    uint96 public rewardLastBidAmount;
    uint256 public rewardBidAmount;
    uint256 public rewardBidAmountSum;

    struct bidSponsorsData {
        address bidder;
        address sponsor;
        uint32 bidTimestamp;
    }

    bidSponsorsData[] bidSponsors;

    struct bidRewardsData {
        address sponsor;
        uint32 timeLeading;
        uint96 amount;
    }

    bidRewardsData[] bidRewards;


    // events
    event LogNewAuction(
        bytes32 tokenHash,
        address auctionSeller,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 startAmount,
        uint32 startDate,
        uint32 endDate,
        uint24 antiSnippingTriggerPeriod,
        uint24 antiSnippingDuration,
        uint256 bidIncremental,
        address auctionSponsor,
        uint8 auctionReward
    );
    event LogAuctionVerified(
        bytes32 tokenHash,
        address auctionSeller,
        address tokenContractAddress,
        uint256 tokenId
    );
    event LogAuctionRefused(
        bytes32 tokenHash,
        address auctionSeller,
        address tokenContractAddress,
        uint256 tokenId
    );
    event LogAuctionClosed(
        address winner,
        uint256 amount,
        uint32 endDate,
        bytes32 biddingHash,
        uint256 blockNumberOfTheLastBidAccepted
    );
    event LogBid(
        uint256 amount,
        uint256 minimal,
        address indexed origin,
        address sponsor,
        bytes32 biddingParentHash,
        bytes32 biddingHash,
        uint8 indexed status
    );
    event LogAntiSnippingTriggered(uint32 endDate);

    event LogSetAuctionEndVoucher(
        address auctionSC,
        address indexed auctionSeller,
        bytes32 tokenHash,
        uint256 amount,
        uint16 rewardsCount,
        bytes voucher,
        bytes32 auctionEndVoucherHash
    );
    event LogAmountSeller(address user, uint amount);

    event LogError(string version, string error);

    constructor (
        address _auctionityDataForAuction,
        bytes _signedRawTxTokenTransfer,
        address _tokenContractAddress,
        uint256 _tokenId,
        bytes _auctionConfig,
        address _sponsor,
        uint8 _reward
    ) public {

        if(!decodeAuctionConfig(_auctionConfig)){
            return;
        }

        auctionityDataForAuction = AuctionityDataForAuction(_auctionityDataForAuction);
        owner = auctionityDataForAuction.owner();
        oracle = auctionityDataForAuction.oracle();
        ethereumChainId = auctionityDataForAuction.ethereumChainId();
        auctionityChainId = auctionityDataForAuction.auctionityChainId();
        auctionityTreasurerEth = AuctionityTreasurerEth(auctionityDataForAuction.auctionityTreasurerAddress());

        signedRawTxTokenTransfer = _signedRawTxTokenTransfer;
        tokenHash = keccak256(_signedRawTxTokenTransfer);

        tokenContractAddress = _tokenContractAddress;
        tokenId = _tokenId;

        if(!getTokenInfoFromTransfer(_signedRawTxTokenTransfer)){
            return;
        }

        auctionityAuctionFactoryAddress = msg.sender;
        auctionSponsor = _sponsor;
        auctionReward = _reward;


        biddingHash = bytes32(address(this));

        emit LogNewAuction(
            tokenHash,
            auctionSeller,
            tokenContractAddress,
            tokenId,
            startAmount,
            startDate,
            endDate,
            antiSnippingTriggerPeriod,
            antiSnippingDuration,
            bidIncremental,
            auctionSponsor,
            auctionReward
        );
    }

    function getTokenInfoFromTransfer(bytes _signedRawTxTokenTransfer) internal returns (bool){
        address _txTokenContractAddress;
        uint _txTokenId;

        (
            _txTokenContractAddress,
            auctionSeller,
            contractDepositAddress,
            _txTokenId
        ) = auctionityDataForAuction.decodeRawTxGetTransferInfo(_signedRawTxTokenTransfer, ethereumChainId, tokenContractAddress);

        if(_txTokenContractAddress == address(0) || _txTokenContractAddress != tokenContractAddress){
            emit LogError(version, "INVALID_ADDRESS_ERC721");
            return false;
        }

        if(contractDepositAddress == address(0)){
            emit LogError(version, "INVALID_ADDRESS_DEPOSIT");
            return false;
        }

        if(_txTokenId != tokenId){
            emit LogError(version, "INVALID_TOKENID_ERC721");
            return false;
        }

        if(auctionSeller == address(0) || auctionSeller != tx.origin){
            emit LogError(version, "INVALID_SELLER");
            return false;
        }

        return true;
    }

    // Modifier
    modifier isOwner() {
        require(msg.sender == owner, "Sender must be owner");
        _;
    }

    modifier isOracle() {
        require(msg.sender == oracle, "Sender must be oracle");
        _;
    }

    modifier isAuctionFactory() {
        require(msg.sender == auctionityAuctionFactoryAddress, "Sender must be auctionFactory");
        _;
    }

    modifier isAuctionVerified() {
        require(state == uint8(auctionState.VERIFIED), "State must be verified");
        _;
    }

    modifier isAuctionClosed() {
        require(state == uint8(auctionState.CLOSED), "State must be closed");
        _;
    }

    // Setter
    function setOracle(address _oracle) public isOwner {
        oracle = _oracle;
    }

    function setTreasurerSC(address _auctionityTreasurerEthSc) public isOwner {
        auctionityTreasurerEth = AuctionityTreasurerEth(_auctionityTreasurerEthSc);
    }

    function setAuctionVerified(bytes32 _tokenHash) public isAuctionFactory {
        if(_tokenHash == tokenHash) {
            state = uint8(auctionState.VERIFIED);
            emit LogAuctionVerified(tokenHash, auctionSeller, tokenContractAddress, tokenId);
            return;
        }
        emit LogError(version, "SET_AUCTION_VERIFIED_FAILED");
    }

    function setAuctionRefused(bytes32 _tokenHash) public isAuctionFactory {
        if(_tokenHash == tokenHash) {
            state = uint8(auctionState.REFUSED);
            emit LogAuctionRefused(tokenHash, auctionSeller, tokenContractAddress, tokenId);
            return;
        }
        emit LogError(version, "SET_AUCTION_REFUSED_FAILED");

    }

    function decodeAuctionConfig(bytes _auctionConfig) internal returns (bool){
        bytes32 _startAmount;
        bytes4 _startDate;
        bytes4 _endDate;
        bytes3 _antiSnippingTriggerPeriod;
        bytes2 _antiSnippingDuration;
        bytes32 _bidIncremental;

        assembly {
            let _ptr := add(_auctionConfig, 0x20)
            _startAmount := mload(_ptr)
            _startDate := mload(add(_ptr, 32))
            _endDate := mload(add(_ptr, 36))
            _antiSnippingTriggerPeriod := mload(add(_ptr, 40))
            _antiSnippingDuration := mload(add(_ptr,43))
            _bidIncremental := mload(add(_ptr,45))
        }

        startAmount = uint256(_startAmount);
        startDate = uint32(_startDate);
        endDate = uint32(_endDate);
        originalEndDate = endDate;
        antiSnippingTriggerPeriod = uint24(_antiSnippingTriggerPeriod);
        antiSnippingDuration = uint16(_antiSnippingDuration);
        bidIncremental = uint256(_bidIncremental);


        if(startDate >= endDate || block.timestamp >= endDate){
            emit LogError(version, "INVALID_DATE_AT_CONTRACT_CREATION");
            return false;
        }

        if(startAmount == 0 ){
            emit LogError(version, "INVALID_START_AMOUNT_AT_CONTRACT_CREATION");
            return false;
        }

        return true;
    }

    /** Biding **/
    function bid(uint256 _amount,address _sponsor, bytes32 _tokenHash) public isAuctionVerified returns (bool) {
        bytes32 biddingParentHash = biddingHash;
        if(block.timestamp < startDate){
            emit LogError(version, "AUCTION_IS_NOT_STARTED_YET");
            return false;
        }

        if(block.timestamp > endDate){
            emit LogError(version, "AUCTION_IS_ALREADY_CLOSED");
            return false;
        }

        if(_tokenHash != tokenHash) {
            emit LogError(version, "AUCTION_BID_TOKENHASH_INVALID");
            return;
        }

        if(msg.sender == auctionSeller){
            emit LogError(version, "AUCTION_OWNER_CAN_NOT_BID");
            return false;
        }

        address _user = msg.sender;
        uint256 _minimal = getMinimalAmount();

        if (_amount < _minimal) {
            biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.AMOUNT_TOO_LOW)));
            emit LogBid(_amount, _minimal, _user, _sponsor, biddingParentHash, biddingHash, uint8(BidStatus.AMOUNT_TOO_LOW));
            return false;
        }

        if (!auctionityTreasurerEth.lockDeposit(_amount, currentLeader)) {
            biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.LOCK_DEPOSIT_FAILED)));
            emit LogBid(_amount, _minimal, _user, _sponsor, biddingParentHash, biddingHash, uint8(BidStatus.LOCK_DEPOSIT_FAILED));
            return false;
        }

        bidSponsorsData memory _bidSponsors = bidSponsorsData({
            bidder: _user,
            sponsor: _sponsor,
            bidTimestamp: uint32(block.timestamp)
        });

        bidSponsors.push(_bidSponsors);
        
        currentLeader = _user;
        currentAmount = _amount;
        _minimal = getMinimalAmount();
        blockNumberOfTheLastBidAccepted = block.number;

        biddingHash = keccak256(abi.encodePacked(biddingHash, _user, _amount, uint8(BidStatus.ACCEPTED)));
        emit LogBid(_amount, _minimal, _user, _sponsor, biddingParentHash, biddingHash, uint8(BidStatus.ACCEPTED));

        if (block.timestamp > endDate-antiSnippingTriggerPeriod) {
            endDate = uint32(block.timestamp + antiSnippingDuration);
            emit LogAntiSnippingTriggered(endDate);
        }

        return true;
    }

    /** Ending **/
    function end() public isAuctionVerified returns (bool) {

        if(block.timestamp <= endDate){
            emit LogError(version, "AUCTION_IS_NOT_CLOSED_YET");
            return false;
        }

        if(state == uint8(auctionState.CLOSED)){
            emit LogError(version, "END_IS_ALREADY_CALLED");
            return false;
        }

        if (currentAmount > 0 && !auctionityTreasurerEth.endorse(currentAmount, currentLeader)) {
            emit LogError(version, "END_ENDORSE_FAILED");
            return false;
        }

        state = uint8(auctionState.CLOSED);

        clubSponsor = auctionityDataForAuction.clubSponsor();
        
        setRewardsAmount();
        setBidRewardsTime();
        bidRewardsTimeLeadingSort();
        setBidRewardsAmount();
        setAmountForSeller();

        emit LogAuctionClosed(currentLeader, currentAmount, endDate, biddingHash, blockNumberOfTheLastBidAccepted);

        return true;
    }

    /////////////////////////////////
    function setAuctionEndVoucher(address _depositContractAddress, bytes memory _oracleRSV, bytes memory _transferData,bytes memory _signedRawTxCreateAuction,bytes memory _signedRawTxBid) public isAuctionClosed isOracle {

        uint _auctionEndVoucherOffset;
        bytes memory _auctionEndVoucherSendData = getAuctionEndVoucherSendData();

        if(!auctionEndVoucherOracleSignatureVerification(_depositContractAddress, _oracleRSV, keccak256(_transferData), keccak256(_auctionEndVoucherSendData))) {
            emit LogError(version, "AUCTION_END_VOUCHER_ORACLE_INVALID_SIGNATURE");
            return;
        }

        if(!auctionEndVoucherCreateVerification(_signedRawTxCreateAuction)) {
            emit LogError(version,'AUCTION_END_VOUCHER_CREATE_TX_INVALID');
            return;
        }

        if(_signedRawTxBid.length <= 1 && currentAmount > 0) {
            emit LogError(version,'AUCTION_END_VOUCHER_BID_TX_NOT_SET');
            return;
        }

        if(_signedRawTxBid.length > 1) {
            if(currentAmount == 0) {
                emit LogError(version,'AUCTION_END_VOUCHER_BID_TX_LENGTH_INVALID');
                return;
            }
            if(!auctionEndVoucherBidVerification(_signedRawTxBid)) {
                emit LogError(version,'AUCTION_END_VOUCHER_BID_TX_INVALID');
                return;
            }
        }

        setAuctionEndVoucherSize(_transferData.length, _signedRawTxCreateAuction.length, _signedRawTxBid.length);
        setAuctionEndVoucherSelector();

        _auctionEndVoucherOffset = setAuctionEndVoucherParam1(_oracleRSV, _transferData);
        _auctionEndVoucherOffset = setAuctionEndVoucherParam2(_auctionEndVoucherOffset,_signedRawTxCreateAuction);
        _auctionEndVoucherOffset = setAuctionEndVoucherParam3(_auctionEndVoucherOffset,_signedRawTxBid);
        setAuctionEndVoucherParam4(_auctionEndVoucherOffset, _auctionEndVoucherSendData);

        emit LogSetAuctionEndVoucher(this, auctionSeller, tokenHash, currentAmount, rewardsCount, auctionEndVoucher, keccak256(_signedRawTxCreateAuction));
    }

    function setAuctionEndVoucherSize(uint _transferDataLength,uint _signedRawTxCreateAuctionLength,uint _signedRawTxBidLength) internal {

        uint _auctionEndVoucherLength =  4 // start of rlp
        + 4 * 32 // 4 param
        + 32 + 32 + 65 + (((_transferDataLength /32) + 1) * 32) // data : length + biddingHash + rsvOracle + transferLength + transferData
        + 32 + (((_signedRawTxCreateAuctionLength /32) + 1) * 32); // length + signedRawTxCreateAuction

        if(currentAmount == 0) {
            _auctionEndVoucherLength += 32 + 32  // length + emptyBytes
            + 32 + 32; // length + emptyBytes
        } else {
            _auctionEndVoucherLength += 32 + (((_signedRawTxBidLength /32) + 1) * 32)  // length + _signedRawTxBid
            + 32 + (((( 52 + 52 + 32 + (rewardsCount * 32) + 2) / 32) + 1) * 32) - 1; //  length + send deposit data
        }

        auctionEndVoucher = new bytes(_auctionEndVoucherLength);
    }

    function setAuctionEndVoucherSelector() internal {
        // 0x9009d9b7 : bytes4(keccak256('auctionEndVoucher(bytes,bytes,bytes,bytes)'))

        bytes4 selector = 0x9009d9b7;
        for(uint8 i = 0; i < 4; i++) {
            auctionEndVoucher[i] = bytes1(selector[i]);
        }
    }

    function setAuctionEndVoucherParam1(bytes _oracleRSV, bytes memory _transferData) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(4*32);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4+i] = bytes1(_bytes32Position[i]);
        }

        bytes32 _bytes32Length = bytes32(32 + 65 + _transferData.length);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
        }

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + 32 + uint(_bytes32Position) + i] = bytes1(biddingHash[i]);
        }

        for(i = 0; i < 65; i++) {
            auctionEndVoucher[4 + 32 + 32 + uint(_bytes32Position) + i] = bytes1(_oracleRSV[i]);
        }

        for(i = 0; i < _transferData.length; i++) {
            auctionEndVoucher[4 + 32 + 32 + 65 + uint(_bytes32Position) + i] = bytes1(_transferData[i]);
        }

        return uint(_bytes32Position) + 32 + ((((32 + 65 + _transferData.length) / 32) + 1) * 32);
    }

    function setAuctionEndVoucherParam2(uint _offset, bytes _signedRawTxCreateAuction) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(_offset);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + 32 + i] = bytes1(_bytes32Position[i]);
        }

        bytes32 _bytes32Length = bytes32(_signedRawTxCreateAuction.length);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
        }

        for(i = 0; i < _signedRawTxCreateAuction.length; i++) {
            auctionEndVoucher[4 + 32 + uint(_bytes32Position) + i] = bytes1(_signedRawTxCreateAuction[i]);
        }

        return uint(_bytes32Position) + 32 + (((_signedRawTxCreateAuction.length / 32) + 1) * 32);
    }

    function setAuctionEndVoucherParam3(uint _offset, bytes _signedRawTxBid) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(_offset);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + 64 + i] = bytes1(_bytes32Position[i]);
        }

        bytes32 _bytes32Length = bytes32(_signedRawTxBid.length);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
        }

        for(i = 0; i < _signedRawTxBid.length; i++) {
            auctionEndVoucher[4 + 32 + uint(_bytes32Position) + i] = bytes1(_signedRawTxBid[i]);
        }

        return uint(_bytes32Position) + 32 + (((_signedRawTxBid.length / 32) + 1) * 32);
    }

    function setAuctionEndVoucherParam4(uint _offset, bytes memory _auctionEndVoucherSendData) internal {
        uint i;
        bytes32 _bytes32Position = bytes32(_offset);

        for(i = 0; i < 32; i++) {
            auctionEndVoucher[4 + 96 + i] = bytes1(_bytes32Position[i]);
        }

        if(currentAmount == 0) {
            for(i = 0; i < 32; i++) {
                auctionEndVoucher[4 + uint(_bytes32Position) + i] = bytes1(0);
            }

        } else {

            bytes32 _bytes32Length = bytes32(_auctionEndVoucherSendData.length);

            for(i = 0; i < 32; i++) {
                auctionEndVoucher[4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
            }

            for(i = 0; i < _auctionEndVoucherSendData.length; i++) {
                auctionEndVoucher[4 + 32 + uint(_bytes32Position) + i] = bytes1(_auctionEndVoucherSendData[i]);
            }
        }
    }

    function auctionEndVoucherCreateVerification(bytes memory _signedRawTxCreateAuction) internal view returns (bool) {
        bytes32 _tokenHash;
        address _auctionFactoryContractAddress;
        address _auctionCreator;
        address _tokenContractAddress;
        uint256 _tokenId;
        uint8 _rewardPercent;

        (
            _tokenHash,
            _auctionFactoryContractAddress,
            _auctionCreator,
            _tokenContractAddress,
            _tokenId,
            _rewardPercent
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetCreateAuctionInfo(_signedRawTxCreateAuction,auctionityChainId);

        return _tokenHash == tokenHash &&
            _auctionFactoryContractAddress == auctionityAuctionFactoryAddress &&
            _auctionCreator == auctionSeller &&
            _tokenContractAddress == tokenContractAddress &&
            _tokenId == tokenId &&
            _rewardPercent == auctionReward;
    }

    function auctionEndVoucherBidVerification(bytes memory _signedRawTxBid) internal view returns (bool) {
        bytes32 _hashRawTxTokenTransferFromBid;
        address _auctionContractAddress;
        address _signerBid;
        uint256 _bidAmount;

        (
            _hashRawTxTokenTransferFromBid,
            _auctionContractAddress,
            _bidAmount,
            _signerBid
        ) = AuctionityLibraryDecodeRawTx.decodeRawTxGetBiddingInfo(_signedRawTxBid,auctionityChainId);

        return _auctionContractAddress == address(this) &&
            _bidAmount == currentAmount &&
            _signerBid == currentLeader;
    }

    function auctionEndVoucherOracleSignatureVerification(
        address _depositContractAddress,
        bytes memory _oracleRSV,
        bytes32 _transferDataHash,
        bytes32 _auctionEndVoucherSendDataHash
    ) internal  returns (bool) {

        // if oracle is the signer of this auction end voucher
        address oracleEcrecoverSigner = AuctionityLibraryDecodeRawTx.ecrecoverSigner(
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(
                            _depositContractAddress,
                            tokenContractAddress,
                            tokenId,
                            auctionSeller,
                            currentLeader,
                            currentAmount,
                            biddingHash,
                            auctionReward,
                            _transferDataHash,
                            _auctionEndVoucherSendDataHash
                        )
                    )
                )
            ),
            _oracleRSV,
            0
        );
        return oracleEcrecoverSigner == oracle;
    }

    // getter
    function getInfos() public view returns (
        address _auctionSeller,
        uint32 _startDate,
        uint32 _endDate,
        uint24 _antiSnippingTriggerPeriod,
        uint16 _antiSnippingDuration,
        uint256 _bidIncremental,
        uint256 _currentAmount,
        uint256 _minimalAmount,
        address _currentLeader,
        bytes32 _biddingHash,
        uint8 _state
    ) {
        return(
            auctionSeller,
            startDate,
            endDate,
            antiSnippingTriggerPeriod,
            antiSnippingDuration,
            bidIncremental,
            currentAmount,
            getMinimalAmount(),
            currentLeader,
            biddingHash,
            state
        );
    }

    function getDates() public view returns(
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

    function getMinimalAmount() public view returns (
        uint256 _minimal
    ) {
        if(currentAmount > 0)
        {
            _minimal = currentAmount.add(bidIncremental);
            return;
        }

        _minimal = startAmount;
    }

    function getCurrentAmounts() public view returns (
        uint256 _current,
        uint256 _minimal
    ) {
        _current = currentAmount;
        _minimal = getMinimalAmount();
    }


    function setRewardsAmount() internal {

        if(auctionReward == 0 || currentAmount == 0) {
            return;
        }

        uint256 rewardAmount = uint256(currentAmount).mul(uint256(auctionReward)).div(100);
        rewardClubAmount = rewardAmount.mul(uint256(rewardClub)).div(100);
        rewardAuctionAmount = uint96(rewardAmount.mul(uint256(rewardAuction)).div(100).div(1000000000)) ; // floor in gwei
        rewardLastBidAmount = uint96(rewardAmount.mul(uint256(rewardLastBid)).div(100).div(1000000000)) ; // floor in gwei
        rewardBidAmount = rewardAmount.mul(uint256(rewardBid)).div(100);
    }

    function setBidRewardsTime() internal {
        if(auctionReward == 0 || currentAmount == 0) {
            return;
        }

        uint _bidSponsorsLength = bidSponsors.length;
        bidRewardsData memory _bidRewards;

        if(_bidSponsorsLength == 0){
            return;
        }

        if(_bidSponsorsLength == 1){

            _bidRewards = bidRewardsData({
                sponsor: bidSponsors[0].sponsor,
                timeLeading: uint32(1),
                amount: uint96(0)
                });

            bidRewards.push(_bidRewards);
            return;
        }

        uint _bidRewardsLength;
        bool _found;
        uint _bidSponsorsIndex;
        uint _bidRewardsIndex;

        for(_bidSponsorsIndex = 0; _bidSponsorsIndex < _bidSponsorsLength - 1 ; _bidSponsorsIndex++) {
            _bidRewardsLength = bidRewards.length;

            _found = false;
            for(_bidRewardsIndex = 0; _bidRewardsIndex < _bidRewardsLength ; _bidRewardsIndex++){
                if(bidRewards[_bidRewardsIndex].sponsor == bidSponsors[_bidSponsorsIndex].sponsor){
                    bidRewards[_bidRewardsIndex].timeLeading = bidRewards[_bidRewardsIndex].timeLeading.add(bidSponsors[_bidSponsorsIndex + 1].bidTimestamp.sub(bidSponsors[_bidSponsorsIndex].bidTimestamp));
                    _found = true;
                    continue;
                }
            }

            if(!_found) {
                _bidRewards = bidRewardsData({
                    sponsor: bidSponsors[_bidSponsorsIndex].sponsor,
                    timeLeading: bidSponsors[_bidSponsorsIndex + 1].bidTimestamp.sub(bidSponsors[_bidSponsorsIndex].bidTimestamp),
                    amount: uint96(0)
                    });

                bidRewards.push(_bidRewards);
            }
        }

        // last bid to end
        _found = false;
        for(_bidRewardsIndex = 0; _bidRewardsIndex < _bidRewardsLength ; _bidRewardsIndex++){
            if(bidRewards[_bidRewardsIndex].sponsor == bidSponsors[_bidSponsorsLength - 1].sponsor){
                bidRewards[_bidRewardsIndex].timeLeading = bidRewards[_bidRewardsIndex].timeLeading.add(endDate.sub(bidSponsors[_bidSponsorsLength - 1].bidTimestamp));
                _found = true;
                continue;
            }
        }

        if(!_found) {
            _bidRewards = bidRewardsData({
                sponsor: bidSponsors[_bidSponsorsLength - 1].sponsor,
                timeLeading: endDate.sub(bidSponsors[_bidSponsorsLength - 1].bidTimestamp),
                amount: uint96(0)
                });

            bidRewards.push(_bidRewards);
        }
    }

    function setBidRewardsAmount() internal {
        if(auctionReward == 0 || currentAmount == 0) {
            return;
        }

        uint _bidRewardsIndex;

        rewardsCount = uint16(bidRewards.length);
        if(rewardsCount > maxReward) {
            rewardsCount = maxReward;
        }

        if(rewardsCount == 0) {
            return;
        }

        uint256 _timeLeadingSum;

        for(_bidRewardsIndex = 0; _bidRewardsIndex < rewardsCount ; _bidRewardsIndex++){
            _timeLeadingSum = _timeLeadingSum.add(uint256(bidRewards[_bidRewardsIndex].timeLeading));
        }

        bool _foundLastBidder;
        address _lastSponsorForLastBidder = getLastSponsorForLastBidder();

        for(_bidRewardsIndex = 0; _bidRewardsIndex < rewardsCount ; _bidRewardsIndex++){
            bidRewards[_bidRewardsIndex].amount = uint96(rewardBidAmount.mul(bidRewards[_bidRewardsIndex].timeLeading)
                .div(_timeLeadingSum)
                .div(1000000000));
            
            rewardBidAmountSum = rewardBidAmountSum.add(uint(bidRewards[_bidRewardsIndex].amount));

            if(bidRewards[_bidRewardsIndex].sponsor == _lastSponsorForLastBidder){
                bidRewards[_bidRewardsIndex].amount = bidRewards[_bidRewardsIndex].amount.add(rewardLastBidAmount);
                _foundLastBidder = true;
            }
        }

        if(_foundLastBidder == false) {
            // add at end of list
            bidRewards[rewardsCount].amount = rewardLastBidAmount;
        }
    }

    function getAuctionEndVoucherSendData() public view returns (bytes memory auctionEndVoucherSendData) {

        if(currentAmount == 0) {
            return;
        }

        auctionEndVoucherSendData = new bytes(52 + 52 + 32 + (rewardsCount * (32)) + 2);
        uint _auctionEndVoucherSendDataOffset;
        uint _auctionEndVoucherSendDataOffsetOfrewardsCount;
        uint i;

        // add seller data
        bytes20 _sendAddress = bytes20(auctionSeller);
        bytes32 _sendAmount32 = bytes32(sellerAmount);
        for(i = 0; i < 20; i++) {
            auctionEndVoucherSendData[i] = bytes1(_sendAddress[i]);
        }

        _auctionEndVoucherSendDataOffset += 20;

        for(i = 0; i < 32; i++) {
            auctionEndVoucherSendData[20+i] = bytes1(_sendAmount32[i]);
        }

        _auctionEndVoucherSendDataOffset += 32;

        // add club data
        _sendAddress = bytes20(clubSponsor);
        _sendAmount32 = bytes32(rewardClubAmount);
        for(i = 0; i < 20; i++) {
            auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAddress[i]);
        }
        _auctionEndVoucherSendDataOffset += 20;
        for(i = 0; i < 32; i++) {
            auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAmount32[i]);
        }
        _auctionEndVoucherSendDataOffset += 32;


        // add deposit rewards data
        _auctionEndVoucherSendDataOffsetOfrewardsCount = _auctionEndVoucherSendDataOffset;
        _auctionEndVoucherSendDataOffset += 2;

        _sendAddress = bytes20(auctionSponsor);
        bytes12 _sendAmount12 = bytes12(rewardAuctionAmount);
        for(i = 0; i < 20; i++) {
            auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAddress[i]);
        }
        _auctionEndVoucherSendDataOffset += 20;
        for(i = 0; i < 12; i++) {
            auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAmount12[i]);
        }
        _auctionEndVoucherSendDataOffset += 12;

        uint16 _realRewardsCount;
        for(uint _bidRewardsIndex = 0; _bidRewardsIndex < rewardsCount ; _bidRewardsIndex++) {
            if(bidRewards[_bidRewardsIndex].amount > uint96(0)){
                _realRewardsCount++;
                _sendAddress = bytes20(bidRewards[_bidRewardsIndex].sponsor);
                _sendAmount12 = bytes12(bidRewards[_bidRewardsIndex].amount);
                for(i = 0; i < 20; i++) {
                    auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAddress[i]);
                }
                _auctionEndVoucherSendDataOffset += 20;
                for(i = 0; i < 12; i++) {
                    auctionEndVoucherSendData[_auctionEndVoucherSendDataOffset+i] = bytes1(_sendAmount12[i]);
                }
                _auctionEndVoucherSendDataOffset += 12;
            }
        }

        auctionEndVoucherSendData[_auctionEndVoucherSendDataOffsetOfrewardsCount] = bytes1(bytes2(_realRewardsCount + 1)[0]);
        auctionEndVoucherSendData[_auctionEndVoucherSendDataOffsetOfrewardsCount + 1] = bytes1(bytes2(_realRewardsCount + 1)[1]);
    }

    function bidRewardsTimeLeadingSort() public {
        if(auctionReward == 0 || currentAmount == 0) {
            return;
        }

        uint _bidRewardsLength = bidRewards.length;
        if(_bidRewardsLength == 0){
            return;
        }

        uint _bidRewardsIndex2;
        uint _bidRewardsSwitchWithIndex;
        address _sponsorTmp;
        uint32 _timeLeadingTmp;
        for(uint _bidRewardsIndex = 0; _bidRewardsIndex < _bidRewardsLength - 1 ; _bidRewardsIndex++){
            _bidRewardsSwitchWithIndex = _bidRewardsIndex;

            for(_bidRewardsIndex2 = _bidRewardsIndex + 1; _bidRewardsIndex2 < _bidRewardsLength ; _bidRewardsIndex2++){
                //emit LogDebug1(bidRewards[_bidRewardsIndex].sponsor,bidRewards[_bidRewardsIndex].timeLeading,bidRewards[_bidRewardsIndex2].sponsor,bidRewards[_bidRewardsIndex2].timeLeading);
                if(bidRewards[_bidRewardsIndex2].timeLeading > bidRewards[_bidRewardsSwitchWithIndex].timeLeading) {
                    _bidRewardsSwitchWithIndex = _bidRewardsIndex2;
                }
            }

            if(_bidRewardsSwitchWithIndex != _bidRewardsIndex) {
                _sponsorTmp = bidRewards[_bidRewardsIndex].sponsor;
                _timeLeadingTmp = bidRewards[_bidRewardsIndex].timeLeading;
                bidRewards[_bidRewardsIndex].sponsor = bidRewards[_bidRewardsSwitchWithIndex].sponsor;
                bidRewards[_bidRewardsIndex].timeLeading = bidRewards[_bidRewardsSwitchWithIndex].timeLeading;
                bidRewards[_bidRewardsSwitchWithIndex].sponsor = _sponsorTmp;
                bidRewards[_bidRewardsSwitchWithIndex].timeLeading = _timeLeadingTmp;
            }
        }
    }

    function getBidRewardsCount() public view returns (uint _bidRewardsCount) {
        return bidRewards.length;
    }

    function getBidRewards(uint _bidRewardsIndex) public view returns (address _bidRewardsSponsor, uint32 _bidRewardsTimeLeading , uint _bidRewardsAmount) {
        return (bidRewards[_bidRewardsIndex].sponsor, bidRewards[_bidRewardsIndex].timeLeading, bidRewards[_bidRewardsIndex].amount);
    }

    function setAmountForSeller() internal {
        if(currentAmount == 0){
            return;
        }

        if(auctionReward == 0) {
            sellerAmount = uint256(currentAmount);
            emit LogAmountSeller(auctionSeller, sellerAmount);

        } else {
            sellerAmount = uint256(currentAmount).sub(rewardClubAmount).sub(uint256(rewardAuctionAmount).mul(1000000000)).sub(uint256(rewardLastBidAmount).mul(1000000000)).sub(uint256(rewardBidAmountSum).mul(1000000000));
            emit LogAmountSeller(auctionSeller, sellerAmount);
        }
    }

    function getLastSponsorForLastBidder() public view returns (address _lastBidderSpondor){
        uint _bidSponsorsLength = bidSponsors.length;
            return bidSponsors[_bidSponsorsLength -1].sponsor;
    }

    function getLastSponsorForBidder(address _bidder) public view returns (address _lastBidderSpondor){
        uint _bidSponsorsLength = bidSponsors.length;
        for(uint i = (_bidSponsorsLength - 1); i >= 0 ; i--){
            if(bidSponsors[i].bidder == _bidder){
                return bidSponsors[i].sponsor;
            }
        }
    }
}
