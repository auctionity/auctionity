pragma solidity ^0.4.24;

import "./AuctionityLibraryDecodeRawTx.sol";
import "./AuctionityAuctionEngPgEth.sol";

contract AuctionityRecorder {
    function getTokenHashState(bytes32 _tokenHash) public returns(uint8);
    function stateIsOK(bytes32 _tokenHash) external returns(bool);
    function setTokenHashOk(bytes32 _tokenHash, address _auctionSeller, address _tokenContractAddress, uint _tokenId) external returns(bool);
    function setTokenHashUsed(bytes32 _tokenHash, address _auctionSeller, address _tokenContractAddress, uint _tokenId) external returns(bool);
    function setTokenHashRefused( bytes32 _tokenHash, address auctionSeller, address tokenContractAddress, uint _tokenId) external returns(bool);
    function verify(bytes32 _tokenHash, address _auctionSeller, address _tokenContractAddress, uint _tokenId) external returns (bool);
}

contract AuctionityAuctionFactory {
    string public version = "auction-factory-v1";

    address public owner;
    address public oracle;
    address public auctionityTreasurerAddress;
    address public auctionityDataForAuctionAddress;
    AuctionityDataForAuction public auctionityDataForAuction;


    AuctionityRecorder public auctionityRecorderSc;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;

    bool public migrationLock;

    // events
    // for comptability with AuctionityAuctionEngPgEth
    event LogNewAuction(
        bytes32 tokenHash,
        address auctionSeller,
        address tokenContractAddress,
        uint tokenId,
        uint256 startAmount,
        uint32 startDate,
        uint32 endDate,
        uint24 antiSnippingTriggerPeriod,
        uint24 antiSnippingDuration,
        uint256 bidIncremental,
        address auctionSponsor,
        uint8 auctionReward
    );

    event LogError(string version, string error);
    event LogErrorWithData(uint8 indexed errorId,bytes32[] data);

    constructor(uint8 _ethereumChainId, uint8 _auctionityChainId) public {
        ethereumChainId = _ethereumChainId;
        auctionityChainId = _auctionityChainId;
        owner = msg.sender;
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

    function setOracle(address _oracle) public isOwner {
        oracle = _oracle;
    }

    modifier migrationLockable() {
        require(!migrationLock || msg.sender == owner, "MIGRATION_LOCKED");
        _;
    }

    function setMigrationLock(bool _lock) public isOwner {
        migrationLock = _lock;
    }

    function setAuctionityRecorderSc(address _auctionityRecorderAddress) public{
        auctionityRecorderSc = AuctionityRecorder(_auctionityRecorderAddress);
    }

    function setAuctionityTreasurerAddress(address _auctionityTreasurerAddress) public isOwner {
        auctionityTreasurerAddress = _auctionityTreasurerAddress;
    }

    function setAuctionityDataForAuctionAddress(address _auctionityDataForAuctionAddress) public isOwner {
        auctionityDataForAuctionAddress = _auctionityDataForAuctionAddress;
        auctionityDataForAuction = AuctionityDataForAuction(_auctionityDataForAuctionAddress);

    }

    function create(
        bytes _signedRawTxTokenTransfer,
        address _tokenContractAddress,
        uint256 _tokenId,
        bytes _auctionConfig,
        address _sponsor,
        uint8 _reward)
    public migrationLockable {
        bytes32 _tokenHash = keccak256(_signedRawTxTokenTransfer);

        address _txTokenContractAddress;
        address _txAuctionSeller;
        uint _txTokenId;

        (
            _txTokenContractAddress,
            _txAuctionSeller,
            ,
            _txTokenId
        ) = auctionityDataForAuction.decodeRawTxGetTransferInfo(
            _signedRawTxTokenTransfer,
            ethereumChainId,
            _tokenContractAddress
        );

        if(_txTokenContractAddress == address(0) || _txAuctionSeller == address(0)) {
            emit LogError(version, "INVALID_TOKEN_TRANSFER_FUNCTION");
            return;
        }

        if(_txTokenContractAddress != _tokenContractAddress) {
            emit LogError(version, "INVALID_CONTRACT_ADDRESS");
            return;
        }

        if(_txTokenId != _tokenId) {
            emit LogError(version, "INVALID_TOKENID");
            return;
        }

        if(_txAuctionSeller != msg.sender) {
            emit LogError(version, "INVALID_SELLER");
            return;
        }

        if(!auctionityRecorderSc.verify(_tokenHash, _txAuctionSeller, _txTokenContractAddress, _txTokenId)) {
            emit LogError(version, "TOKENHASH_ALREADY_EXIST");
            return;
        }

        address _contractAddress = new AuctionityAuctionEngPgEth(
            auctionityDataForAuctionAddress,
            _signedRawTxTokenTransfer,
            _tokenContractAddress,
            _tokenId,
            _auctionConfig,
            _sponsor,
            _reward
        );

        check(_contractAddress, _tokenHash, _txAuctionSeller, _txTokenContractAddress, _txTokenId);
    }

    function check(address _auctionSC,bytes32 _tokenHash, address _auctionSeller, address _tokenContractAddress, uint _tokenId) internal{
        if(auctionityRecorderSc.stateIsOK(_tokenHash)){
            auctionityRecorderSc.setTokenHashUsed(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);
            AuctionityAuctionEngPgEth auctionityAuctionEngPgEth = AuctionityAuctionEngPgEth(_auctionSC);
            auctionityAuctionEngPgEth.setAuctionVerified(_tokenHash);
        }
    }

    function setTokenHashOk(
        address _auctionSC,
        bytes32 _tokenHash,
        address _auctionSeller,
        address _tokenContractAddress,
        uint _tokenId
    ) public isOracle {
        if(auctionityRecorderSc.setTokenHashOk(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId)) {
            if(_auctionSC != address(0)) {
                auctionityRecorderSc.setTokenHashUsed(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId);
                AuctionityAuctionEngPgEth auctionityAuctionEngPgEth = AuctionityAuctionEngPgEth(_auctionSC);
                auctionityAuctionEngPgEth.setAuctionVerified(_tokenHash);
            }
        } else {
            emit LogError(version, "SET_STATE_AT_OK_FAILED");
        }
    }

    function setTokenHashRefused(
        address _auctionSC,
        bytes32 _tokenHash, 
        address _auctionSeller, 
        address _tokenContractAddress, 
        uint _tokenId
    ) public isOracle {
        if(auctionityRecorderSc.setTokenHashRefused(_tokenHash, _auctionSeller, _tokenContractAddress, _tokenId)) {
            if(_auctionSC != address(0)) {
                AuctionityAuctionEngPgEth auctionityAuctionEngPgEth = AuctionityAuctionEngPgEth(_auctionSC);
                auctionityAuctionEngPgEth.setAuctionRefused(_tokenHash);
            }
        }
        else {
            emit LogError(version, "SET_STATE_AT_REFUSED_FAILED");
        }
    }
}
